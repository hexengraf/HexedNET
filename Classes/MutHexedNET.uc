class MutHexedNET extends HxMutator
    config(HexedMutators);

struct HxNTClassOverride
{
    var class<Weapon> TargetClass;
    var class<Weapon> BASClass;
    var array<class<WeaponFire> > FireModeClass;
};

const MIN_TIMESTEP = 0.0165;
const WARMUP_COUNT = 10;
const AVG_DELTA_RATIO = 0.3;

var config float MaxPingFrequency;
var config int LagCompensationLimit;
var config int ProjectileCompensationLimit;
var config bool bRubberbandingFix;
var config bool bLinkMeshes;

var const private array<HxNTClassOverride> ClassOverrides;
var private array<HxNTPawnTracker> PawnTrackers;
var private HxNTPawnTracker PCC;
var private array<HxNTProjectileTracker> ProjectileTrackers;
var private float AvgDeltaTime;
var private float ForwardTimeStep;
var private int TickCount;

event PostBeginPlay()
{
    Super.PostBeginPlay();
    if (!bDeleteMe && !bPendingDelete)
    {
        ApplyClassOverridesToMutators();
        if (bRubberbandingFix)
        {
            Level.Game.PlayerControllerClassName = string(class'HxNTPlayer');
        }
    }
}

function SetProperty(int Index, string Value)
{
    local HxNTClient Client;
    local int i;

    Super.SetProperty(Index, Value);
    if (Properties[Index].Name == "ProjectileCompensationLimit")
    {
        for (i = 0; i < Channels.Length; ++i)
        {
            Client = HxNTClient(Channels[i].GetClientReplicationInfo(UID));
            Client.SetProjectileCompensationLimit(Value);
        }
    }
}

function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    if (TickCount < WARMUP_COUNT)
    {
        ++TickCount;
        AvgDeltaTime = AvgDeltaTime + (DeltaTime - AvgDeltaTime) / TickCount;
    }
    else
    {
        AvgDeltaTime = AvgDeltaTime + (DeltaTime - AvgDeltaTime) * AVG_DELTA_RATIO;
    }
    ForwardTimeStep = FMax(MIN_TIMESTEP, AvgDeltaTime);
}

function bool MutatorIsAllowed()
{
    return Super.MutatorIsAllowed() && Level.NetMode != NM_Standalone;
}

function AddMutator(Mutator M)
{
    Super.AddMutator(M);
    if (M.DefaultWeaponName != "")
    {
        ApplyClassOverridesToMutator(M);
    }
}

function DriverEnteredVehicle(Vehicle V, Pawn P)
{
    local HxNTPawnTracker Tracker;

    Tracker = FindPawnTracker(P);
    if (Tracker != None)
    {
        Tracker.SetTracked(V);
    }
    Super.DriverEnteredVehicle(V, P);
}

function DriverLeftVehicle(Vehicle V, Pawn P)
{
    local HxNTPawnTracker Tracker;

    Tracker = FindPawnTracker(V);
    if (Tracker != None)
    {
        Tracker.SetTracked(P);
    }
    Super.DriverLeftVehicle(V, P);
}

function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
    if (xPawn(Other) != None)
    {
        SpawnPawnTracker(xPawn(Other));
    }
    else if (Weapon(Other) != None)
    {
        ApplyClassOverridesToWeapon(Weapon(Other));
    }
    else if (xWeaponBase(Other) != None)
    {
        ApplyClassOverridesToWeaponBase(xWeaponBase(Other));
    }
    else if (WeaponPickup(Other) != None)
    {
        ApplyClassOverridesToWeaponPickup(WeaponPickup(Other));
    }
    else if (WeaponLocker(Other) != None)
    {
        ApplyClassOverridesToWeaponLocker(WeaponLocker(Other));
    }
    return Super.CheckReplacement(Other, bSuperRelevant);
}

function string GetInventoryClassOverride(string InventoryClassName)
{
    local int i;

    InventoryClassName = Super.GetInventoryClassOverride(InventoryClassName);
    for (i = 0; i < ClassOverrides.Length; ++i)
    {
        if (InventoryClassName ~= string(ClassOverrides[i].TargetClass))
        {
            if (ClassOverrides[i].BASClass != None)
            {
                return string(ClassOverrides[i].BASClass);
            }
            break;
        }
    }
    return InventoryClassName;
}

function Rewind(float CompensationTime)
{
    local int i;

    for (i = PawnTrackers.Length - 1; i >= 0; --i)
    {
        if (PawnTrackers[i].Tracked == None)
        {
            PawnTrackers[i].Destroy();
            PawnTrackers.Remove(i, 1);
        }
        else
        {
            PawnTrackers[i].Rewind(CompensationTime);
        }
    }
    for (i = ProjectileTrackers.Length - 1; i >= 0; --i)
    {
        if (ProjectileTrackers[i] == None)
        {
            ProjectileTrackers.Remove(i, 1);
        }
        else
        {
            ProjectileTrackers[i].Rewind(CompensationTime);
        }
    }
}

function UndoRewind()
{
    local int i;

    for (i = PawnTrackers.Length - 1; i >= 0; --i)
    {
        if (PawnTrackers[i].Tracked == None)
        {
            PawnTrackers[i].Destroy();
            PawnTrackers.Remove(i, 1);
        }
        else
        {
            PawnTrackers[i].UndoRewind();
        }
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

function SpawnPawnTracker(Pawn P)
{
    local int i;

    i = PawnTrackers.Length;
    PawnTrackers[i] = Spawn(class'HxNTPawnTracker', Self);
    PawnTrackers[i].SetTracked(P);
    PrunePawnTrackers();
}

function HxNTPawnTracker FindPawnTracker(Pawn P)
{
    local int i;

    for (i = 0; i < PawnTrackers.Length; ++i)
    {
        if (P == PawnTrackers[i].Tracked)
        {
            return PawnTrackers[i];
        }
    }
    return None;
}

function PrunePawnTrackers()
{
    local int i;

    for (i = PawnTrackers.Length - 1; i >= 0; --i)
    {
        if (PawnTrackers[i].Tracked == None)
        {
            PawnTrackers[i].Destroy();
            PawnTrackers.Remove(i, 1);
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
        if (Hit.IsA('HxNTPawnTracker'))
        {
            Pawn = HxNTPawnTracker(Hit).Tracked;
            if (Pawn != None && (bHitInstigator || Pawn != Weapon.Instigator))
            {
                PastLocation = HitLocation;
                HitLocation = HxNTPawnTracker(Hit).GetPresentHitLocation(HitLocation);
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
function ForwardLinearProjectile(Weapon W, Projectile P, float CompensationTime)
{
    local Vector Extent;
    local Vector Start;
    local Vector HitLocation;
    local Vector HitNormal;
    local Actor Hit;
    local float RemainingTime;
    local float TimeStep;
    local float Counter;

    DisableCollision(P);
    Extent = P.GetCollisionExtent();
    RemainingTime = CompensationTime;
    while (RemainingTime > 0.0)
    {
        TimeStep = FMin(ForwardTimeStep, RemainingTime);
        RemainingTime -= TimeStep;
        Counter += TimeStep;
        Start = P.Location;
        P.AutonomousPhysics(TimeStep);
        Rewind(RemainingTime);
        Hit = RewoundTrace(W, HitLocation, HitNormal, P.Location, Start, Extent);
        if (Hit != None)
        {
            P.SetLocation(HitLocation);
            break;
        }
        if (ForwardProjectileTimer(P, TimeStep, Counter))
        {
            Extent = P.GetCollisionExtent();
        }
    }
    UndoRewind();
    if (P != None && !P.bDeleteMe)
    {
        ForwardProjectileLifeSpan(P, CompensationTime, Counter);
        RestoreCollision(P);
    }
}

function ForwardLinearProjectiles(Weapon W, array<Projectile> Projectiles, float CompensationTime)
{
    local Vector Extent;
    local Vector Start;
    local Vector HitLocation;
    local Vector HitNormal;
    local Actor Hit;
    local float RemainingTime;
    local float TimeStep;
    local array<float> Counters;
    local array<byte> Done;
    local int i;

    Done.Length = Projectiles.Length;
    Counters.Length = Projectiles.Length;
    for (i = 0; i < Projectiles.Length; ++i)
    {
        if (Projectiles[i] != None)
        {
            DisableCollision(Projectiles[i]);
        }
    }
    RemainingTime = CompensationTime;
    while (RemainingTime > 0.0)
    {
        TimeStep = FMin(ForwardTimeStep, RemainingTime);
        RemainingTime -= TimeStep;
        for (i = 0; i < Projectiles.Length; ++i)
        {
            if (Done[i] == 1 || Projectiles[i] == None)
            {
                continue;
            }
            Extent = Projectiles[i].GetCollisionExtent();
            Start = Projectiles[i].Location;
            Projectiles[i].AutonomousPhysics(TimeStep);
            Rewind(RemainingTime);
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
            if (Done[i] == 0)
            {
                ForwardProjectileTimer(Projectiles[i], TimeStep, Counters[i]);
            }
        }
    }
    UndoRewind();
    for (i = 0; i < Projectiles.Length; ++i)
    {
        if (Projectiles[i] != None && !Projectiles[i].bDeleteMe)
        {
            RestoreCollision(Projectiles[i]);
            ForwardProjectileLifeSpan(Projectiles[i], CompensationTime, Counters[i]);
        }
    }
}

// TODO: find a clean way to fix sliding on walls if hit is right outside the extrapolation range.
// Stupid native code uses the remaining movement delta to calculate a sliding movement instead of
// checking the Velocity vector (which would be zeroed out by HitWall).
function ForwardFallingProjectile(Weapon W,
                                  Projectile P,
                                  float CompensationTime,
                                  optional bool bSticky)
{
    local Vector Extent;
    local Vector Start;
    local Actor Hit;
    local Vector HitLocation;
    local Vector HitNormal;
    local float RemainingTime;
    local float TimeStep;
    local float Counter;

    DisableCollision(P);
    Extent = P.GetCollisionExtent();
    RemainingTime = CompensationTime;
    while (RemainingTime > 0.0)
    {
        TimeStep = FMin(ForwardTimeStep, RemainingTime);
        RemainingTime -= TimeStep;
        Start = P.Location;
        P.AutonomousPhysics(TimeStep);
        Rewind(RemainingTime);
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
        if (ForwardProjectileTimer(P, TimeStep, Counter))
        {
            Extent = P.GetCollisionExtent();
        }
    }
    UndoRewind();
    if (P != None && !P.bDeleteMe)
    {
        RestoreCollision(P);
        ForwardProjectileLifeSpan(P, CompensationTime, Counter);
        if (bSticky && Hit != None && !Hit.IsA('Pawn') && !Hit.IsA('Projectile'))
        {
            P.HitWall(HitNormal, Hit);
        }
    }
}

function ForwardBouncingProjectile(Weapon W, Projectile P, float CompensationTime)
{
    local Vector Extent;
    local Vector Start;
    local Vector PreviousVelocity;
    local Actor Hit;
    local Vector HitLocation;
    local Vector HitNormal;
    local float RemainingTime;
    local float TimeStep;
    local float Counter;
    local bool bHitInstigator;

    DisableCollision(P);
    Extent = P.GetCollisionExtent();
    RemainingTime = CompensationTime;
    while (RemainingTime > 0.0)
    {
        TimeStep = FMin(ForwardTimeStep, RemainingTime);
        RemainingTime -= TimeStep;
        Start = P.Location;
        PreviousVelocity = P.Velocity;
        P.AutonomousPhysics(TimeStep);
        Rewind(RemainingTime);
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
        if (ForwardProjectileTimer(P, TimeStep, Counter))
        {
            Extent = P.GetCollisionExtent();
        }
    }
    UndoRewind();
    if (P != None && !P.bDeleteMe)
    {
        ForwardProjectileLifeSpan(P, CompensationTime, Counter);
        RestoreCollision(P);
    }
}

function ApplyClassOverridesToMutators()
{
    local Mutator M;

    for (M = Level.Game.BaseMutator; M != None; M = M.NextMutator)
    {
        if (M.DefaultWeaponName != "")
        {
            ApplyClassOverridesToMutator(M);
        }
    }
}

function ApplyClassOverridesToMutator(Mutator M)
{
    local int i;

    for (i = 0; i < ClassOverrides.Length; ++i)
    {
        if (M.DefaultWeaponName ~= string(ClassOverrides[i].TargetClass))
        {
            if (ClassOverrides[i].BASClass != None)
            {
                M.DefaultWeaponName = string(ClassOverrides[i].BASClass);
                if (M.DefaultWeapon != None)
                {
                    M.DefaultWeapon = class<Weapon>(
                        DynamicLoadObject(M.DefaultWeaponName, class'Class'));
                }
                if (MutInstaGib(M) != None)
                {
                    MutInstaGib(M).WeaponName = ClassOverrides[i].BASClass.Name;
                    MutInstaGib(M).WeaponString = M.DefaultWeaponName;
                }
            }
            break;
        }
    }
}

function ApplyClassOverridesToWeapon(Weapon W)
{
    local int i;
    local int j;

    for (i = 0; i < ClassOverrides.Length; ++i)
    {
        if (W.Class == ClassOverrides[i].TargetClass)
        {
            for (j = 0; j < ClassOverrides[i].FireModeClass.Length; ++j)
            {
                if (ClassOverrides[i].FireModeClass[j] != None)
                {
                    W.FireModeClass[j] = ClassOverrides[i].FireModeClass[j];
                }
            }
            break;
        }
    }
}

function ApplyClassOverridesToWeaponBase(xWeaponBase B)
{
    local int i;

    for (i = 0; i < ClassOverrides.Length; ++i)
    {
        if (B.WeaponType == ClassOverrides[i].TargetClass)
        {
            if (ClassOverrides[i].BASClass != None)
            {
                B.WeaponType = ClassOverrides[i].BASClass;
            }
            break;
        }
    }
}

function ApplyClassOverridesToWeaponPickup(WeaponPickup P)
{
    local int i;

    for (i = 0; i < ClassOverrides.Length; ++i)
    {
        if (P.InventoryType == ClassOverrides[i].TargetClass)
        {
            if (ClassOverrides[i].BASClass != None)
            {
                P.InventoryType = ClassOverrides[i].BASClass;
            }
            break;
        }
    }
}

function ApplyClassOverridesToWeaponLocker(WeaponLocker L)
{
    local int i;
    local int j;

    for (i = 0; i < L.Weapons.Length; ++i)
    {
        for (j = 0; j < ClassOverrides.Length; ++j)
        {
            if (L.Weapons[i].WeaponClass == ClassOverrides[j].TargetClass)
            {
                if (ClassOverrides[j].BASClass != None)
                {
                    L.Weapons[i].WeaponClass = ClassOverrides[j].BASClass;
                }
                break;
            }
        }
    }
}

final function float NormalizePing(float Ping)
{
    return FClamp(Ping, 0.0, GetCompensationLimit());
}

final function float GetCompensationLimit()
{
    return LagCompensationLimit / (Level.TimeDilation * 1000.0);
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

static final function ForwardProjectileLifeSpan(Projectile P, float CompensationTime, float Counter)
{
    // TODO: This right here is one of the arguments for forwarding only half ping.
    // We subtract half ping from the life-span instead of full ping because the server did a full
    // ping forward + the natural delay of half ping for the projectile to reach the client.
    // So we're effectively forwarding space by full ping and time by half ping.
    CompensationTime = CompensationTime / 2.0;
    if (P.LifeSpan > 0.0)
    {
        P.LifeSpan = FMax(FMin(0.05, P.LifeSpan), P.LifeSpan - CompensationTime);
    }
    if (P.TimerRate > 0.0 && !P.bTimerLoop)
    {
        P.SetTimer(P.TimerRate - Counter, false);
    }
}

static final function bool ForwardProjectileTimer(Projectile P, float TimeStep, out float Counter)
{
    if (P.TimerRate > 0.0)
    {
        Counter += TimeStep;
        if (Counter >= P.TimerRate)
        {
            P.Timer();
            Counter = 0.0;
            if (!P.bTimerLoop || P.TimerRate == 0.0)
            {
                P.SetTimer(0.0, false);
            }
            return true;
        }
    }
    return false;
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
    Range = Normal(Start - End) * 100.0;
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
    Description="Provides lag compensation for official weapons."
    bAddToServerPackages=true
    UniqueObjectName="HexedNET"
    ClientReplicationInfoClass=class'HxNTClient'
    Properties(0)=(Name="MaxPingFrequency",Type=HX_PROPERTY_Float,LowerLimit="0.2",UpperLimit="10.0")
    Properties(1)=(Name="LagCompensationLimit",Type=HX_PROPERTY_Int,LowerLimit="50",UpperLimit="999")
    Properties(2)=(Name="ProjectileCompensationLimit",Type=HX_PROPERTY_Int,LowerLimit="50",UpperLimit="999")
    Properties(3)=(Name="bRubberbandingFix",Type=HX_PROPERTY_Bool)
    Properties(4)=(Name="bLinkMeshes",Type=HX_PROPERTY_Bool)
    DisplayInfo(0)=(Caption="Maximum Ping Frequency",Hint="Maximum frequency to send pings (pings/second).",bMPOnly=true,bAdvanced=true)
    DisplayInfo(1)=(Caption="Lag Compensation Limit",Hint="Global lag compensation limit (in milliseconds).",Step="10",bMPOnly=true,bAdvanced=true)
    DisplayInfo(2)=(Caption="Projectile Compensation Limit",Hint="Projectile-specific lag compensation limit (in milliseconds).",Step="10",bMPOnly=true,bAdvanced=true)
    DisplayInfo(3)=(Caption="Backport Rubberbanding Fix",Hint="Backport OldUnreal's rubberbanding fix. Applied on restart/map change.",bMPOnly=true,bAdvanced=true)
    DisplayInfo(4)=(Caption="Link Meshes",Hint="Link meshes for collision detection. Disable this if experiencing crashes.",bMPOnly=true,bAdvanced=true)
    ConfigClasses(0)=class'HxNetcodeConfig'
    Priority=64
    ClassOverrides(0)=(TargetClass=class'AssaultRifle',BASClass=class'HxNet_AssaultRifle',FireModeClass=(class'HxNet_AssaultFire',class'HxNet_AssaultGrenade'))
    ClassOverrides(1)=(TargetClass=class'BioRifle',BASClass=class'HxNet_BioRifle',FireModeClass=(class'HxNet_BioFire',class'HxNet_BioChargedFire'))
    ClassOverrides(2)=(TargetClass=class'ShockRifle',BASClass=class'HxNet_ShockRifle',FireModeClass=(class'HxNet_ShockBeamFire',class'HxNet_ShockProjFire'))
    ClassOverrides(3)=(TargetClass=class'LinkGun',BASClass=class'HxNet_LinkGun',FireModeClass=(class'HxNet_LinkAltFire',class'HxNet_LinkFire'))
    ClassOverrides(4)=(TargetClass=class'MiniGun',FireModeClass=(class'HxNet_MiniGunFire',class'HxNet_MiniGunAltFire'))
    ClassOverrides(5)=(TargetClass=class'FlakCannon',BASClass=class'HxNet_FlakCannon',FireModeClass=(class'HxNet_FlakFire',class'HxNet_FlakAltFire'))
    ClassOverrides(6)=(TargetClass=class'RocketLauncher',BASClass=class'HxNet_RocketLauncher',FireModeClass=(class'HxNet_RocketFire',class'HxNet_RocketMultiFire'))
    ClassOverrides(7)=(TargetClass=class'SniperRifle',BASClass=class'HxNet_SniperRifle',FireModeClass=(class'HxNet_SniperFire'))
    ClassOverrides(8)=(TargetClass=class'ClassicSniperRifle',BASClass=class'HxNet_ClassicSniperRifle',FireModeClass=(class'HxNet_ClassicSniperFire'))
    ClassOverrides(9)=(TargetClass=class'SuperShockRifle',BASClass=class'HxNet_SuperShockRifle',FireModeClass=(class'HxNet_SuperShockBeamFire',class'HxNet_SuperShockBeamFire'))
    ClassOverrides(10)=(TargetClass=class'ZoomSuperShockRifle',BASClass=class'HxNet_ZoomSuperShockRifle',FireModeClass=(class'HxNet_ZoomSuperShockBeamFire'))
    ClassOverrides(11)=(TargetClass=class'HxSuperShockRifle',BASClass=class'HxNet_HxSuperShockRifle',FireModeClass=(class'HxNet_SuperShockBeamFire',class'HxNet_SuperShockBeamFire'))
    ClassOverrides(12)=(TargetClass=class'HxZoomSuperShockRifle',BASClass=class'HxNet_HxZoomSuperShockRifle',FireModeClass=(class'HxNet_ZoomSuperShockBeamFire'))
    MaxPingFrequency=10.0
    LagCompensationLimit=330
    ProjectileCompensationLimit=132
    bRubberbandingFix=false
    bLinkMeshes=true
}
