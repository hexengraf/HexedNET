class MutHexedNET extends HxMutator
    config(HexedMutators);

// TODO: Revisit this later, different values result in different amounts of error.
// Maybe it should be the average DeltaTime from the client? But then players with super high FPS
// and super high ping will cause an abusive amount of iterations.
const BASE_TIMESTEP = 0.02;

var config float MaxPingFrequency;
var config int PingCompensationLimit;
var config int ProjectileCompensationLimit;
var config bool bRubberbandingFix;
var config bool bLinkMeshes;

var const private class<Weapon> WeaponClasses[11];
var const private class<Weapon> NewNetWeaponClasses[11];
var const private class<WeaponFire> WeaponFireClasses[4];
var const private class<WeaponFire> NewNetWeaponFireClasses[4];
var private PawnCollisionCopy PCC;
var private array<HxNet_ShockProjectile> ShockProjectiles;
var private HxNTClock NETClock;

event PostBeginPlay()
{
    Super.PostBeginPlay();
    if (!bDeleteMe && !bPendingDelete)
    {
        NETClock = Spawn(class'HxNTClock', Self);
        ApplyNewNetWeaponsOnMutators();
        if (bRubberbandingFix)
        {
            Level.Game.PlayerControllerClassName = string(class'HxNTPlayer');
        }
    }
}

function bool MutatorIsAllowed()
{
    return Super.MutatorIsAllowed() && Level.NetMode != NM_Standalone;
}

function ApplyNewNetWeaponsOnMutators()
{
    local Mutator M;

    for (M = Level.Game.BaseMutator; M != None; M = M.NextMutator)
    {
        if (M.DefaultWeaponName != "")
        {
            ApplyNewNetWeapons(M);
        }
    }
}

function ApplyNewNetWeapons(Mutator M)
{
    local int i;

    for (i = 0; i < ArrayCount(WeaponClasses); ++i)
    {
        if (M.DefaultWeaponName ~= string(WeaponClasses[i]))
        {
            M.DefaultWeaponName = string(NewNetWeaponClasses[i]);
            if (M.DefaultWeapon != None)
            {
                M.DefaultWeapon = class<Weapon>(
                    DynamicLoadObject(M.DefaultWeaponName, class'Class'));
            }
            if (MutInstaGib(M) != None)
            {
                MutInstaGib(M).WeaponName = NewNetWeaponClasses[i].Name;
                MutInstaGib(M).WeaponString = M.DefaultWeaponName;
            }
        }
    }
}

function AddMutator(Mutator M)
{
    Super.AddMutator(M);
    if (M.DefaultWeaponName != "")
    {
        ApplyNewNetWeapons(M);
    }
}

function ModifyPlayer(Pawn Other)
{
    if (PCC == None)
    {
        PCC = Spawn(class'PawnCollisionCopy', Self);
        PCC.SetPawn(Other);
    }
    else
    {
        PCC.AddPawnToList(Other);
    }
    PCC = PCC.RemoveOldPawns();
    Super.ModifyPlayer(Other);
}

function TimeTravel(float DeltaTime)
{
    if (PCC != None)
    {
        PCC.TimeTravel(DeltaTime);
    }
    RewindShockProjectiles(DeltaTime);
}

function UnTimeTravel()
{
    if (PCC != None)
    {
        PCC.UnTimeTravel();
    }
    RestoreShockProjectiles();
}

// We need to do 2 traces. First, one that ignores the things which have already been copied
// and a second one that looks only for things that are copied
function Actor TimeTravelTrace(Weapon Weapon,
                               out vector HitLocation,
                               out vector HitNormal,
                               vector End,
                               vector Start,
                               optional vector Extent,
                               optional bool bHitInstigator)
{
    local Actor Other;
    local PawnCollisionCopy Copy;
    local vector PCCHitNormal;
    local vector PCCHitLocation;

    // First, lets set the extent of our trace.  End once we hit an actor which won't
    // be checked by an unlagged copy.
    foreach TraceActors(class'Actor', Other, HitLocation, HitNormal, End, Start, Extent)
    {
        if ((Other.bBlockActors || Other.bProjTarget || Other.bWorldGeometry)
            && !IsPredicted(Other))
        {
            End = HitLocation;
            break;
        }
    }
    // Now, lets see if we run into any copies, we stop at the location
    // determined by the previous trace.
    foreach TraceActors(
        class'PawnCollisionCopy', Copy, PCCHitLocation, PCCHitNormal, End, Start, Extent)
    {
        if (Copy != None && Copy.CopiedPawn != None
            && (bHitInstigator || Copy.CopiedPawn != Weapon.Instigator))
        {
            HitLocation = PCCHitLocation;
            HitNormal = PCCHitNormal;
            return Copy;
        }
    }
    return Other;
}

function Actor CompensatedTrace(Weapon Weapon,
                                out vector HitLocation,
                                out vector HitNormal,
                                vector End,
                                vector Start,
                                optional out vector PastHitLocation)
{
    local Actor Other;

    Other = TimeTravelTrace(Weapon, PastHitLocation, HitNormal, End, Start);
    if (Other != None && Other.IsA('PawnCollisionCopy'))
    {
        HitLocation = PawnCollisionCopy(Other).GetPresentHitLocation(PastHitLocation);
        return PawnCollisionCopy(Other).CopiedPawn;
    }
    HitLocation = PastHitLocation;
    return Other;
}

function bool IsReasonable(Weapon W, Vector V)
{
    local vector LocDiff;

    if (Pawn(W.Owner) == None)
    {
        return true;
    }
    LocDiff = V - (Pawn(W.Owner).Location + Pawn(W.Owner).EyePosition());
    // clErr = (LocDiff dot LocDiff);
    // if (clErr > 500.0*NETClock.AverDT)
        // PlayerController(Pawn(Owner).Controller).ClientMessage("Exceeded error"@clErr);
    // Log(ClErr@(Pawn(Owner).Velocity dot Pawn(Owner).Velocity));
    // if(clErr >= 750) Log("ERROR TOO GREAT");
    return (LocDiff dot LocDiff) < 1250.0;
}

function DriverEnteredVehicle(Vehicle V, Pawn P)
{
    local PawnCollisionCopy C;

    C = PCC;
    while (C != None)
    {
        if (C.CopiedPawn == P)
        {
            C.SetPawn(V);
            break;
        }
        C = C.Next;
    }
    Super.DriverEnteredVehicle(V, P);
}

function DriverLeftVehicle(Vehicle V, Pawn P)
{
    local PawnCollisionCopy C;

    C = PCC;
    while (C != None)
    {
        if (C.CopiedPawn == V)
        {
            C.SetPawn(P);
            break;
        }
        C = C.Next;
    }
    Super.DriverLeftVehicle(V, P);
}

function ListPawns()
{
    local PawnCollisionCopy PCC2;

    for (PCC2 = PCC; PCC2 != None; PCC2 = PCC2.Next)
    {
       PCC2.Identify();
    }
}

function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
    local WeaponLocker L;
    local int i;
    local int j;

    if (Weapon(Other) != None)
    {
        for (i = 0; i < ArrayCount(Weapon(Other).FireModeClass); ++i)
        {
            for (j = 0; j < ArrayCount(WeaponFireClasses); ++j)
            {
                if (Weapon(Other).FireModeClass[i] == WeaponFireClasses[j])
                {
                    Weapon(Other).FireModeClass[i] = NewNetWeaponFireClasses[j];
                    break;
                }
            }
        }
    }
    else if (xWeaponBase(Other) != None)
    {
        for (i = 0; i < ArrayCount(WeaponClasses); ++i)
        {
            if (xWeaponBase(Other).WeaponType == WeaponClasses[i])
            {
                xWeaponBase(Other).WeaponType = NewNetWeaponClasses[i];
            }
        }
    }
    else if (WeaponPickup(Other) != None)
    {
        for (i = 0; i < ArrayCount(WeaponClasses); ++i)
        {
            if (WeaponPickup(Other).InventoryType == WeaponClasses[i])
            {
                WeaponPickup(Other).InventoryType = NewNetWeaponClasses[i];
            }
        }
    }
    else if (WeaponLocker(Other) != None)
    {
        L = WeaponLocker(Other);
        for (i = 0; i < ArrayCount(WeaponClasses); ++i)
        {
            for (j = 0; j < L.Weapons.Length; ++j)
            {
                if (L.Weapons[j].WeaponClass == WeaponClasses[i])
                {
                    L.Weapons[j].WeaponClass = NewNetWeaponClasses[i];
                }
            }
        }
    }
    return Super.CheckReplacement(Other, bSuperRelevant);
}

function string GetInventoryClassOverride(string InventoryClassName)
{
    local int i;

    InventoryClassName = Super.GetInventoryClassOverride(InventoryClassName);
    for (i = 0; i < ArrayCount(WeaponClasses); ++i)
    {
        if (InventoryClassName ~= string(WeaponClasses[i]))
        {
            return string(NewNetWeaponClasses[i]);
        }
    }
    return InventoryClassName;
}

function RewindShockProjectiles(float DeltaTime)
{
    local int i;

    DeltaTime = FMin(DeltaTime, GetDeltaTimeLimit());
    for (i = ShockProjectiles.Length - 1; i >= 0; --i)
    {
        if (ShockProjectiles[i] == None)
        {
            ShockProjectiles.Remove(i, 1);
        }
        else
        {
            ShockProjectiles[i].RewindLocation(DeltaTime);
        }
    }
}

function RestoreShockProjectiles()
{
    local int i;

    for (i = ShockProjectiles.Length - 1; i >= 0; --i)
    {
        if (ShockProjectiles[i] == None)
        {
            ShockProjectiles.Remove(i, 1);
        }
        else
        {
            ShockProjectiles[i].RestoreLocation();
        }
    }
}

function RegisterShockProjectile(HxNet_ShockProjectile P)
{
    if (P != None)
    {
        ShockProjectiles[ShockProjectiles.Length] = P;
        P.Register(Self);
    }
}

function RemoveShockProjectile(HxNet_ShockProjectile P)
{
    local int i;

    for (i = 0; i < ShockProjectiles.Length; ++i)
    {
        if (ShockProjectiles[i] == P)
        {
            ShockProjectiles.Remove(i, 1);
            break;
        }
    }
}

function float GetDeltaTimeLimit()
{
    return PingCompensationLimit / 1000.0;
}

// TODO: find a clean way to fix sliding on walls if hit is right outside the extrapolation range.
// Stupid native code uses the remaining movement delta to calculate a sliding movement instead of
// checking the Velocity vector (which would be zeroed out by HitWall).
function Projectile ExtrapolateFallingProjectile(ProjectileFire Fire,
                                                 Vector Start,
                                                 Rotator Dir,
                                                 Vector Velocity,
                                                 float DeltaTime,
                                                 optional Vector Extent,
                                                 optional bool bSwitchToZeroExtent)
{
    local Projectile P;
    local PhysicsVolume Volume;
    local Vector PreviousVelocity;
    local Vector Delta;
    local Vector End;
    local Actor Hit;
    local Vector HitLocation;
    local Vector HitNormal;
    local Actor ZeroCollider;
    local Vector ZeroHitLocation;
    local float TimeStep;

    while (DeltaTime > 0)
    {
        Volume = Level.GetPhysicsVolume(Start);
        PreviousVelocity = Velocity;
        TimeStep = FMin(BASE_TIMESTEP, DeltaTime);
        DeltaTime -= TimeStep;
        Delta = AdvanceFalling(Volume, Velocity, TimeStep);
        End = Start + Delta;
        TimeTravel(DeltaTime);
        Hit = TimeTravelTrace(Fire.Weapon, HitLocation, HitNormal, End, Start, Extent);
        if (Hit != None && bSwitchToZeroExtent && SwitchToZeroExtent(Fire, Hit, Start, HitLocation))
        {
            Extent = Vect(0, 0, 0);
            bSwitchToZeroExtent = false;
            ZeroHitLocation = HitLocation;
            ZeroCollider = Hit;
            Hit = TimeTravelTrace(Fire.Weapon, HitLocation, HitNormal, End, Start);
        }
        if (Hit != None)
        {
            if (Hit.IsA('PawnCollisionCopy'))
            {
                // TODO: what about self-inflicted splash damage if target is close?
                // By updating to collide in the current target location (instead of past location),
                // players might wrongfully avoid self-inflicted splash damage.
                HitLocation += PawnCollisionCopy(Hit).GetLocationDelta();
            }
            Start = HitLocation;
            break;
        }
        Velocity = AdjustFallingVelocity(Volume, PreviousVelocity, Delta, TimeStep);
        Start = End;
    }
    UnTimeTravel();
    P = SpawnProjectile(Fire, Start, Dir, ZeroHitLocation, ZeroCollider);
    if (P != None && P.Physics == PHYS_Falling)
    {
        P.Velocity = Velocity;
        if (Hit != None)
        {
            P.Move(End - Start);
            if (P != None && !P.bDeleteMe && !Hit.IsA('Pawn'))
            {
                P.HitWall(HitNormal, Hit);
            }
        }
    }
    return P;
}

static final function Vector ExtrapolateFalling(PhysicsVolume Volume,
                                                Vector Start,
                                                float DeltaTime,
                                                out Vector Velocity)
{
    local Vector PreviousVelocity;
    local Vector Delta;

    PreviousVelocity = Velocity;
    Delta = AdvanceFalling(Volume, Velocity, DeltaTime);
    Velocity = AdjustFallingVelocity(Volume, PreviousVelocity, Delta, DeltaTime);
    return Start + Delta;
}

static final function Vector AdvanceFalling(PhysicsVolume Volume,
                                            out Vector Velocity,
                                            float DeltaTime)
{
    if (Volume.bWaterVolume)
    {
        Velocity *= 1.0 - Volume.FluidFriction * DeltaTime;
    }
    Velocity += Volume.Gravity * DeltaTime * 0.5;
    return (Velocity + Volume.ZoneVelocity) * DeltaTime;
}

static final function Vector AdjustFallingVelocity(PhysicsVolume Volume,
                                                   Vector PreviousVelocity,
                                                   Vector Delta,
                                                   float DeltaTime)
{
    local Vector Velocity;

    Velocity = Delta / DeltaTime - Volume.ZoneVelocity;
    if (Velocity.Z < PreviousVelocity.Z || PreviousVelocity.Z >= 0)
    {
        Velocity = 2 * Velocity - PreviousVelocity;
    }
    if (VSize(Velocity) > Volume.TerminalVelocity)
    {
        Velocity = Normal(Velocity) * Volume.TerminalVelocity;
    }
    return Velocity;
}

static function bool SwitchToZeroExtent(ProjectileFire Fire, Actor Hit, Vector Start, Vector End)
{
    local Actor OtherHit;
    local Vector HitLocation;
    local Vector HitNormal;
    local Vector Range;

    if (Hit.bBlockZeroExtentTraces
        && (Hit.StaticMesh == None
            || (StaticMeshActor(Hit) != None && !StaticMeshActor(Hit).bExactProjectileCollision)))
    {
        return false;
    }
    Range = Normal(Start - End) * 100;
    OtherHit = Fire.Trace(HitLocation, HitNormal, Start + Range, End, true);
    if (OtherHit == None)
    {
        OtherHit = Fire.Trace(HitLocation, HitNormal, End, Start + Range, true);
    }
    else
    {
        OtherHit = Fire.Trace(HitLocation, HitNormal, End, HitLocation, true);
    }
    return OtherHit == None;
}

static function Projectile SpawnProjectile(ProjectileFire Fire,
                                           Vector Start,
                                           Rotator Dir,
                                           Vector ZeroHitLocation,
                                           Actor ZeroCollider)
{
    Local Projectile P;

    if (ZeroCollider == None)
    {
        P = Fire.SpawnProjectile(Start, Dir);
    }
    else
    {
        P = Fire.SpawnProjectile(ZeroHitLocation, Dir);
        if (P != None)
        {
            P.SetCollisionSize(0, 0);
            P.bSwitchToZeroCollision = false;
            P.ZeroCollider = ZeroCollider;
            P.Move(Start - ZeroHitLocation);
        }
    }
    return P;
}

static function Vector GetClearHitLocation(Vector HitLocation,
                                           Vector HitNormal,
                                           Vector Direction,
                                           float Clearance,
                                           float Limit)
{
    local float Ratio;

    Ratio = Abs(Direction Dot HitNormal);
    Limit = 1 / Limit;
    if (Ratio < Limit)
    {
        return HitLocation - (Direction * Limit);
    }
    return HitLocation - (Direction * (Clearance / Ratio));
}

static function bool IsPredicted(Actor A)
{
    return A.IsA('xPawn') || (A.IsA('Vehicle') && Vehicle(A).Driver != None);
}

defaultproperties
{
    FriendlyName="HexedNET %TAG%"
    Description="Modified version of UTComp's enhanced netcode (ping compensation)."
    bAddToServerPackages=true
    CRIClass=class'HxNTClient'
    Properties(0)=(Name="MaxPingFrequency",Type=HX_PROPERTY_Float,LowerLimit="0.2",UpperLimit="20.0")
    Properties(1)=(Name="PingCompensationLimit",Type=HX_PROPERTY_Int,LowerLimit="50",UpperLimit="999")
    Properties(2)=(Name="ProjectileCompensationLimit",Type=HX_PROPERTY_Int,LowerLimit="50",UpperLimit="999")
    Properties(3)=(Name="bRubberbandingFix",Type=HX_PROPERTY_Bool)
    Properties(4)=(Name="bLinkMeshes",Type=HX_PROPERTY_Bool)
    DisplayInfo(0)=(Caption="Maximum Ping Frequency",Hint="Maximum frequency to send pings (pings/second).",bMPOnly=true,bAdvanced=true)
    DisplayInfo(1)=(Caption="Ping Compensation Limit",Hint="Global ping compensation limit (in milliseconds) applied to all weapon types.",Step="10",bMPOnly=true,bAdvanced=true)
    DisplayInfo(2)=(Caption="Projectile Compensation Limit",Hint="Ping compensation limit (in milliseconds) applied to projectiles.",Step="10",bMPOnly=true,bAdvanced=true)
    DisplayInfo(3)=(Caption="Backport Rubberbanding Fix",Hint="Backport OldUnreal's rubberbanding fix. Applied on restart/map change.",bMPOnly=true,bAdvanced=true)
    DisplayInfo(4)=(Caption="Link Meshes",Hint="Link meshes for collision detection. Disable this if experiencing crashes.",bMPOnly=true,bAdvanced=true)
    bDisableTick=true

    // configs
    MaxPingFrequency=10.0
    PingCompensationLimit=350
    ProjectileCompensationLimit=75
    bRubberbandingFix=false
    bLinkMeshes=true
    //original weapons
    WeaponClasses(0)=class'ShockRifle'
    WeaponClasses(1)=class'LinkGun'
    WeaponClasses(2)=class'FlakCannon'
    WeaponClasses(3)=class'RocketLauncher'
    WeaponClasses(4)=class'SniperRifle'
    WeaponClasses(5)=class'ClassicSniperRifle'
    WeaponClasses(6)=class'BioRifle'
    WeaponClasses(7)=class'SuperShockRifle'
    WeaponClasses(8)=class'ZoomSuperShockRifle'
    WeaponClasses(9)=class'HxSuperShockRifle'
    WeaponClasses(10)=class'HxZoomSuperShockRifle'
    // replaced NewNet classes
    NewNetWeaponClasses(0)=class'HxNet_ShockRifle'
    NewNetWeaponClasses(1)=class'NewNet_LinkGun'
    NewNetWeaponClasses(2)=class'HxNet_FlakCannon'
    NewNetWeaponClasses(3)=class'NewNet_RocketLauncher'
    NewNetWeaponClasses(4)=class'HxNet_SniperRifle'
    NewNetWeaponClasses(5)=class'HxNet_ClassicSniperRifle'
    NewNetWeaponClasses(6)=class'HxNet_BioRifle'
    NewNetWeaponClasses(7)=class'HxNet_SuperShockRifle'
    NewNetWeaponClasses(8)=class'HxNet_ZoomSuperShockRifle'
    NewNetWeaponClasses(9)=class'HxNet_HxSuperShockRifle'
    NewNetWeaponClasses(10)=class'HxNet_HxZoomSuperShockRifle'
    WeaponFireClasses(0)=class'AssaultFire'
    WeaponFireClasses(1)=class'AssaultGrenade'
    WeaponFireClasses(2)=class'MiniGunFire'
    WeaponFireClasses(3)=class'MiniGunAltFire'
    NewNetWeaponFireClasses(0)=class'NewNet_AssaultFire'
    NewNetWeaponFireClasses(1)=class'NewNet_AssaultGrenade'
    NewNetWeaponFireClasses(2)=class'NewNet_MiniGunFire'
    NewNetWeaponFireClasses(3)=class'NewNet_MiniGunAltFire'
}
