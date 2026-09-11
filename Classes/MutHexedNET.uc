class MutHexedNET extends HxMutator
    config(HexedMutators);

const MIN_TIMESTEP = 0.0165;
const WARMUP_COUNT = 10;
const AVG_DELTA_RATIO = 0.3;

var config float MaxPingFrequency;
var config int PingCompensationLimit;
var config int ProjectileCompensationLimit;
var config bool bRubberbandingFix;
var config bool bLinkMeshes;

var const private class<Weapon> WeaponClasses[12];
var const private class<Weapon> NewNetWeaponClasses[12];
var const private class<WeaponFire> WeaponFireClasses[2];
var const private class<WeaponFire> NewNetWeaponFireClasses[2];
var private PawnCollisionCopy PCC;
var private array<HxNTProjectileTracker> ProjectileTrackers;
var private float AverageDeltaTime;
var private float ForwardTimestep;
var private int TickCount;

event PostBeginPlay()
{
    Super.PostBeginPlay();
    if (!bDeleteMe && !bPendingDelete)
    {
        ApplyNewNetWeaponsOnMutators();
        if (bRubberbandingFix)
        {
            Level.Game.PlayerControllerClassName = string(class'HxNTPlayer');
        }
    }
}

function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    if (TickCount < WARMUP_COUNT)
    {
        TickCount++;
        AverageDeltaTime += (DeltaTime - AverageDeltaTime) / TickCount;
    }
    else
    {
        AverageDeltaTime += (DeltaTime - AverageDeltaTime) * AVG_DELTA_RATIO;
    }
    ForwardTimestep = FMax(MIN_TIMESTEP, AverageDeltaTime);
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

function bool IsReasonable(Weapon W, Vector V)
{
    local Vector LocDiff;

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

function Rewind(float DeltaTime)
{
    local int i;

    DeltaTime = FMin(DeltaTime, GetDeltaTimeLimit());
    if (PCC != None)
    {
        PCC.Rewind(DeltaTime);
    }
    for (i = ProjectileTrackers.Length - 1; i >= 0; --i)
    {
        if (ProjectileTrackers[i] == None)
        {
            ProjectileTrackers.Remove(i, 1);
        }
        else
        {
            ProjectileTrackers[i].Rewind(DeltaTime);
        }
    }
}

function UndoRewind()
{
    local int i;

    if (PCC != None)
    {
        PCC.UndoRewind();
    }
    for (i = ProjectileTrackers.Length - 1; i >= 0; --i)
    {
        if (ProjectileTrackers[i] == None)
        {
            ProjectileTrackers.Remove(i, 1);
        }
        else
        {
            ProjectileTrackers[i].UndoRewind();
        }
    }
}

function RemoveProjectileTracker(HxNTProjectileTracker Tracker)
{
    local int i;

    for (i = 0; i < ProjectileTrackers.Length; ++i)
    {
        if (ProjectileTrackers[i] == Tracker)
        {
            ProjectileTrackers.Remove(i, 1);
            break;
        }
    }
}

function RegisterShockProjectile(HxNet_ShockProjectile P)
{
    local HxNTProjectileTracker Tracker;

    if (P != None)
    {
        Tracker = Spawn(class'HxNTProjectileTracker', Self);
        P.SetTracker(Tracker);
        ProjectileTrackers[ProjectileTrackers.Length] = Tracker;
    }
}

function Actor RewoundTrace(Weapon Weapon,
                            out Vector HitLocation,
                            out Vector HitNormal,
                            Vector End,
                            Vector Start,
                            optional Vector Extent,
                            optional bool bHitInstigator,
                            optional Vector PastLocation)
{
    local Actor Hit;
    local Actor Pawn;

    foreach TraceActors(class'Actor', Hit, HitLocation, HitNormal, End, Start, Extent)
    {
        if (Hit.IsA('PawnCollisionCopy'))
        {
            Pawn = PawnCollisionCopy(Hit).CopiedPawn;
            if (Pawn != None && (bHitInstigator || Pawn != Weapon.Instigator))
            {
                PastLocation = HitLocation;
                HitLocation = PawnCollisionCopy(Hit).GetPresentHitLocation(HitLocation);
                Hit = Pawn;
                break;
            }
        }
        else if (Hit.IsA('HxNTProjectileTracker'))
        {
            PastLocation = HitLocation;
            Hit = HxNTProjectileTracker(Hit).GetTracked(HitLocation);
            if (Hit != None)
            {
                break;
            }
        }
        else if ((Hit.bBlockActors || Hit.bProjTarget || Hit.bWorldGeometry) && !IsPredicted(Hit))
        {
            PastLocation = HitLocation;
            break;
        }
    }
    return Hit;
}

// TODO: handle bSwitchToZeroCollision
function ForwardLinearProjectile(Weapon W, Projectile P, float DeltaTime)
{
    local Vector Extent;
    local Vector Start;
    local Vector HitLocation;
    local Vector HitNormal;
    local Actor Hit;
    local float Counter;
    local float TimeStep;

    DisableCollision(P);
    Extent = P.GetCollisionExtent();
    while (DeltaTime > 0)
    {
        TimeStep = FMin(ForwardTimestep, DeltaTime);
        DeltaTime -= TimeStep;
        Counter += TimeStep;
        Start = P.Location;
        P.AutonomousPhysics(TimeStep);
        Rewind(DeltaTime);
        Hit = RewoundTrace(W, HitLocation, HitNormal, P.Location, Start, Extent);
        if (Hit != None)
        {
            P.SetLocation(HitLocation);
            break;
        }
        if (P.TimerRate > 0 && Counter >= P.TimerRate)
        {
            P.Timer();
            Counter = 0;
            Extent = P.GetCollisionExtent();
        }
    }
    UndoRewind();
    RestoreCollision(P);
}

function ForwardLinearProjectiles(Weapon W, array<Projectile> Projectiles, float DeltaTime)
{
    local Vector Extent;
    local Vector Start;
    local Vector HitLocation;
    local Vector HitNormal;
    local Actor Hit;
    local float Counter;
    local float TimeStep;
    local array<byte> Done;
    local int i;

    Done.Length = Projectiles.Length;
    for (i = 0; i < Projectiles.Length; ++i)
    {
        if (Projectiles[i] != None)
        {
            DisableCollision(Projectiles[i]);
        }
    }
    while (DeltaTime > 0)
    {
        TimeStep = FMin(ForwardTimestep, DeltaTime);
        DeltaTime -= TimeStep;
        Counter += TimeStep;
        for (i = 0; i < Projectiles.Length; ++i)
        {
            if (Done[i] == 1 || Projectiles[i] == None)
            {
                continue;
            }
            Extent = Projectiles[i].GetCollisionExtent();
            Start = Projectiles[i].Location;
            Projectiles[i].AutonomousPhysics(TimeStep);
            Rewind(DeltaTime);
            Hit = RewoundTrace(W, HitLocation, HitNormal, Projectiles[i].Location, Start, Extent);
            if (Hit != None)
            {
                Projectiles[i].SetLocation(HitLocation);
                Done[i] = 1;
                if (Projectiles[i].IsA('RocketProj'))
                {
                    class'HxNet_RocketProj'.static.RemoveFromFlock(RocketProj(Projectiles[i]));
                }
            }
        }
        for (i = 0; i < Projectiles.Length; ++i)
        {
            if (Done[i] == 0 && Projectiles[i].TimerRate > 0
                && Counter >= Projectiles[i].TimerRate)
            {
                Projectiles[i].Timer();
                Counter = 0;
            }
        }
    }
    UndoRewind();
    for (i = 0; i < Projectiles.Length; ++i)
    {
        if (Projectiles[i] != None)
        {
            RestoreCollision(Projectiles[i]);
        }
    }
}

// TODO: find a clean way to fix sliding on walls if hit is right outside the extrapolation range.
// Stupid native code uses the remaining movement delta to calculate a sliding movement instead of
// checking the Velocity vector (which would be zeroed out by HitWall).
function ForwardFallingProjectile(Weapon W, Projectile P, float DeltaTime, optional bool bSticky)
{
    local Vector Extent;
    local Vector Start;
    local Actor Hit;
    local Vector HitLocation;
    local Vector HitNormal;
    local float Counter;
    local float TimeStep;

    DisableCollision(P);
    Extent = P.GetCollisionExtent();
    while (DeltaTime > 0)
    {
        TimeStep = FMin(ForwardTimestep, DeltaTime);
        DeltaTime -= TimeStep;
        Start = P.Location;
        P.AutonomousPhysics(TimeStep);
        Rewind(DeltaTime);
        Hit = RewoundTrace(W, HitLocation, HitNormal, P.Location, Start, Extent);
        if (Hit != None && P.bSwitchToZeroCollision
            && SwitchToZeroCollision(W, Hit, Start, HitLocation))
        {
            Extent = Vect(0, 0, 0);
            P.bSwitchToZeroCollision = false;
            P.ZeroCollider = Hit;
            Hit = RewoundTrace(W, HitLocation, HitNormal, P.Location, Start);
        }
        if (Hit != None)
        {
            P.SetLocation(HitLocation);
            break;
        }
        if (P.TimerRate > 0 && Counter >= P.TimerRate)
        {
            P.Timer();
            Counter = 0;
            Extent = P.GetCollisionExtent();
        }
    }
    UndoRewind();
    RestoreCollision(P);
    if (bSticky && Hit != None && !Hit.IsA('Pawn') && !Hit.IsA('Projectile'))
    {
        if (P != None && !P.bDeleteMe)
        {
            P.HitWall(HitNormal, Hit);
        }
    }
}

function ForwardBouncingProjectile(Weapon W, Projectile P, float DeltaTime)
{
    local Vector Extent;
    local Vector Start;
    local Vector PreviousVelocity;
    local Actor Hit;
    local Vector HitLocation;
    local Vector HitNormal;
    local float TimeStep;
    local bool bHitInstigator;

    P.SetPropertyText("bForwarded", "true");
    DisableCollision(P);
    Extent = P.GetCollisionExtent();
    while (DeltaTime > 0)
    {
        TimeStep = FMin(ForwardTimestep, DeltaTime);
        DeltaTime -= TimeStep;
        Start = P.Location;
        PreviousVelocity = P.Velocity;
        P.AutonomousPhysics(TimeStep);
        Rewind(DeltaTime);
        Hit = RewoundTrace(W, HitLocation, HitNormal, P.Location, Start, Extent, bHitInstigator);
        if (Hit != None)
        {
            if (!Hit.IsA('Pawn'))
            {
                UndoRewind();
                P.SetLocation(Start);
                RestoreCollision(P);
                if (P != None)
                {
                    P.Velocity = PreviousVelocity;
                    P.AutonomousPhysics(TimeStep);
                }
                if (P == None || P.bDeleteMe)
                {
                    break;
                }
                DisableCollision(P);
            }
            else
            {
                P.SetLocation(HitLocation);
                break;
            }
            bHitInstigator = true;
        }
    }
    UndoRewind();
    RestoreCollision(P);
}

final function float GetDeltaTimeLimit()
{
    return PingCompensationLimit / 1000.0;
}

static final function bool IsPredicted(Actor A)
{
    return A.IsA('xPawn') || (A.IsA('Vehicle') && Vehicle(A).Driver != None);
}

static final function DisableCollision(Actor A)
{
    A.bCollideWorld = false;
    A.SetCollision(false, false);
}

static final function RestoreCollision(Actor A)
{
    if (A != None)
    {
        A.bCollideWorld = A.default.bCollideWorld;
        A.SetCollision(A.default.bCollideActors, A.default.bBlockActors);
    }
}

static final function bool SwitchToZeroCollision(Weapon W, Actor Hit, Vector Start, Vector End)
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
    OtherHit = W.Trace(HitLocation, HitNormal, Start + Range, End, true);
    if (OtherHit == None)
    {
        OtherHit = W.Trace(HitLocation, HitNormal, End, Start + Range, true);
    }
    else
    {
        OtherHit = W.Trace(HitLocation, HitNormal, End, HitLocation, true);
    }
    return OtherHit == None;
}

static final function Vector GetClearance(Vector HitNormal,
                                          Vector Direction,
                                          float Clearance,
                                          float Limit)
{
    local float Ratio;

    Ratio = Abs(Direction Dot HitNormal);
    Limit = 1 / Limit;
    if (Ratio < Limit)
    {
        return Direction * Limit;
    }
    return Direction * (Clearance / Ratio);
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

    // configs
    MaxPingFrequency=10.0
    PingCompensationLimit=350
    ProjectileCompensationLimit=75
    bRubberbandingFix=false
    bLinkMeshes=true
    //original weapons
    WeaponClasses(0)=class'AssaultRifle'
    WeaponClasses(1)=class'BioRifle'
    WeaponClasses(2)=class'ShockRifle'
    WeaponClasses(3)=class'LinkGun'
    WeaponClasses(4)=class'FlakCannon'
    WeaponClasses(5)=class'RocketLauncher'
    WeaponClasses(6)=class'SniperRifle'
    WeaponClasses(7)=class'ClassicSniperRifle'
    WeaponClasses(8)=class'SuperShockRifle'
    WeaponClasses(9)=class'ZoomSuperShockRifle'
    WeaponClasses(10)=class'HxSuperShockRifle'
    WeaponClasses(11)=class'HxZoomSuperShockRifle'
    // replaced NewNet classes
    NewNetWeaponClasses(0)=class'HxNet_AssaultRifle'
    NewNetWeaponClasses(1)=class'HxNet_BioRifle'
    NewNetWeaponClasses(2)=class'HxNet_ShockRifle'
    NewNetWeaponClasses(3)=class'HxNet_LinkGun'
    NewNetWeaponClasses(4)=class'HxNet_FlakCannon'
    NewNetWeaponClasses(5)=class'HxNet_RocketLauncher'
    NewNetWeaponClasses(6)=class'HxNet_SniperRifle'
    NewNetWeaponClasses(7)=class'HxNet_ClassicSniperRifle'
    NewNetWeaponClasses(8)=class'HxNet_SuperShockRifle'
    NewNetWeaponClasses(9)=class'HxNet_ZoomSuperShockRifle'
    NewNetWeaponClasses(10)=class'HxNet_HxSuperShockRifle'
    NewNetWeaponClasses(11)=class'HxNet_HxZoomSuperShockRifle'
    WeaponFireClasses(0)=class'MiniGunFire'
    WeaponFireClasses(1)=class'MiniGunAltFire'
    NewNetWeaponFireClasses(0)=class'HxNet_MiniGunFire'
    NewNetWeaponFireClasses(1)=class'HxNet_MiniGunAltFire'
}
