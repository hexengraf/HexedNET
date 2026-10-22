class MutHexedNET extends HxMutator
    config(HexedMutators);

struct HxNTFireModeOverride
{
    var class<WeaponFire> TargetClass;
    var class<WeaponFire> NETClass;
};

struct HxNTClassOverride
{
    var class<Weapon> TargetClass;
    var class<Weapon> NETClass;
    var array<HxNTFireModeOverride> FireModeOverrides;
};

const WARMUP_COUNT = 10;
const DELTA_TIME_ALPHA = 0.008;

var config float PingFrequency;
var config int LagCompensationLimit;
var config int ProjectileCompensationLimit;
var config int MaxCollisionCheckRate;
var config bool bBoostedAimSynchronization;
var config bool bForceStartFireRPCs;
var config bool bClientSideCollisions;
var config int CSCTolerance;
var config bool bRubberbandingFix;
var config bool bLinkMeshes;

var const private array<HxNTClassOverride> ClassOverrides;
var private array<HxNTPawnTracker> PawnTrackers;
var private HxNTPawnTracker PCC;
var private array<HxNTProjectileTracker> ProjectileTrackers;
var private float AvgDT;
var private float FwdTimeStep;
var private int TickCount;
var private bool bReplaceWeapons;

event PostBeginPlay()
{
    Super.PostBeginPlay();
    if (!bDeleteMe && !bPendingDelete)
    {
        ApplyFireModeOverrides();
        if (bBoostedAimSynchronization)
        {
            ApplyClassOverridesToMutators();
            bReplaceWeapons = true;
        }
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
        AvgDT = AvgDT + (DeltaTime - AvgDT) / TickCount;
    }
    else
    {
        AvgDT = AvgDT + (DeltaTime - AvgDT) * DELTA_TIME_ALPHA;
    }
    FwdTimeStep = FMax(1.0 / MaxCollisionCheckRate * Level.TimeDilation, AvgDT);
}

function bool MutatorIsAllowed()
{
    return Super.MutatorIsAllowed() && Level.NetMode != NM_Standalone;
}

function AddMutator(Mutator M)
{
    Super.AddMutator(M);
    if (bReplaceWeapons && M.DefaultWeaponName != "")
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
    else if (bReplaceWeapons)
    {
        if (xWeaponBase(Other) != None)
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
    }
    return Super.CheckReplacement(Other, bSuperRelevant);
}

function string GetInventoryClassOverride(string InventoryClassName)
{
    local int i;

    InventoryClassName = Super.GetInventoryClassOverride(InventoryClassName);
    if (bReplaceWeapons)
    {
        for (i = 0; i < ClassOverrides.Length; ++i)
        {
            if (InventoryClassName ~= string(ClassOverrides[i].TargetClass))
            {
                if (ClassOverrides[i].NETClass != None)
                {
                    return string(ClassOverrides[i].NETClass);
                }
                break;
            }
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
            break;
        }
        else if ((Hit.bBlockActors || Hit.bProjTarget || Hit.bWorldGeometry) && !IsTracked(Hit))
        {
            PastLocation = HitLocation;
            break;
        }
    }
    return Hit;
}

function Actor ReconTrace(Weapon Weapon,
                          out Vector HitLocation,
                          out Vector HitNormal,
                          Vector End,
                          Vector Start,
                          float CompensationTime,
                          Actor ClientHit,
                          optional Vector PastLocation)
{
    local Actor Other;
    local Actor Hit;
    local float OlderTime;
    local float NewerTime;
    local float TimeStep;
    local float Limit;
    local int StepCount;
    local int i;

    Rewind(CompensationTime);
    Hit = RewoundTrace(Weapon, HitLocation, HitNormal, End, Start,,, PastLocation);
    if (ClientHit != None && Hit != ClientHit
        && (IsTracked(ClientHit) || (Hit != None && IsTracked(Hit))))
    {
        TimeStep = AvgDT * 0.5;
        StepCount = 2 * CSCTolerance + 1;
        Limit = GetCompensationLimit();
        OlderTime = CompensationTime;
        NewerTime = CompensationTime;
        for (i = 1; i < StepCount; ++i)
        {
            if (NewerTime > 0.0)
            {
                NewerTime = FMax(CompensationTime - i * TimeStep, 0.0);
                Rewind(NewerTime);
                Other = RewoundTrace(Weapon, HitLocation, HitNormal, End, Start,,, PastLocation);
                if (Other == ClientHit)
                {
                    return Other;
                }
            }
            if (OlderTime < Limit)
            {
                OlderTime = FMin(CompensationTime + i * TimeStep, Limit);
                Rewind(OlderTime);
                Other = RewoundTrace(Weapon, HitLocation, HitNormal, End, Start,,, PastLocation);
                if (Other == ClientHit)
                {
                    return Other;
                }
            }
        }
        Rewind(CompensationTime);
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
        TimeStep = FMin(FwdTimeStep, RemainingTime);
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
    if (P != None)
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
        TimeStep = FMin(FwdTimeStep, RemainingTime);
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
                if (Projectiles[i].IsA('RocketProj'))
                {
                    class'HxNet_RocketProj'.static.RemoveFromFlock(RocketProj(Projectiles[i]));
                }
                Projectiles[i].SetLocation(HitLocation);
                Done[i] = 1;
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
        if (Projectiles[i] != None)
        {
            ForwardProjectileLifeSpan(Projectiles[i], CompensationTime, Counters[i]);
            RestoreCollision(Projectiles[i]);
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
        TimeStep = FMin(FwdTimeStep, RemainingTime);
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
    if (P != None)
    {
        ForwardProjectileLifeSpan(P, CompensationTime, Counter);
        RestoreCollision(P);
        if (P != None && bSticky && Hit != None && !Hit.IsA('Pawn') && !Hit.IsA('Projectile'))
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
        TimeStep = FMin(FwdTimeStep, RemainingTime);
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
    if (P != None)
    {
        RestoreCollision(P);
        ForwardProjectileLifeSpan(P, CompensationTime, Counter);
    }
}

function ApplyClassOverridesToMutators()
{
    local Mutator M;

    if (bReplaceWeapons)
    {
        for (M = Level.Game.BaseMutator; M != None; M = M.NextMutator)
        {
            if (M.DefaultWeaponName != "")
            {
                ApplyClassOverridesToMutator(M);
            }
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
            if (ClassOverrides[i].NETClass != None)
            {
                M.DefaultWeaponName = string(ClassOverrides[i].NETClass);
                if (M.DefaultWeapon != None)
                {
                    M.DefaultWeapon = class<Weapon>(
                        DynamicLoadObject(M.DefaultWeaponName, class'Class'));
                }
                if (MutInstaGib(M) != None)
                {
                    MutInstaGib(M).WeaponName = ClassOverrides[i].NETClass.Name;
                    MutInstaGib(M).WeaponString = M.DefaultWeaponName;
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
            if (ClassOverrides[i].NETClass != None)
            {
                B.WeaponType = ClassOverrides[i].NETClass;
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
            if (ClassOverrides[i].NETClass != None)
            {
                P.InventoryType = ClassOverrides[i].NETClass;
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
                if (ClassOverrides[j].NETClass != None)
                {
                    L.Weapons[i].WeaponClass = ClassOverrides[j].NETClass;
                }
                break;
            }
        }
    }
}

function ServerTraveling(string URL, bool bItems)
{
    Super.ServerTraveling(URL, bItems);
    RestoreFireModeOverrides();
}

final function float GetAverageDeltaTime()
{
    return AvgDT;
}

final function float GetCompensationLimit()
{
    return (LagCompensationLimit * Level.TimeDilation) * 0.001;
}

static final function bool IsTracked(Actor A)
{
    return A.IsA('xPawn') || (A.IsA('Vehicle') && Vehicle(A).Driver != None)
        || A.IsA('HxNet_ShockProjectile');
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

static function ApplyFireModeOverrides()
{
    local int i;
    local int j;

    for (i = 0; i < default.ClassOverrides.Length; ++i)
    {
        for (j = 0; j < default.ClassOverrides[i].FireModeOverrides.Length; ++j)
        {
            default.ClassOverrides[i].TargetClass.default.FireModeClass[j] =
                default.ClassOverrides[i].FireModeOverrides[j].NETClass;
        }
    }
}

static function RestoreFireModeOverrides()
{
    local int i;
    local int j;

    for (i = 0; i < default.ClassOverrides.Length; ++i)
    {
        for (j = 0; j < default.ClassOverrides[i].FireModeOverrides.Length; ++j)
        {
            default.ClassOverrides[i].TargetClass.default.FireModeClass[j] =
                default.ClassOverrides[i].FireModeOverrides[j].TargetClass;
        }
    }
}

defaultproperties
{
    FriendlyName="HexedNET %TAG%"
    Description="Provides lag compensation for official weapons."
    bAddToServerPackages=true
    QualifiedName="HexedNET"
    ClientReplicationInfoClass=class'HxNTClient'
    Properties(0)=(Name="PingFrequency",Type=HX_PROPERTY_Float,LowerLimit="0.5",UpperLimit="20.0")
    Properties(1)=(Name="LagCompensationLimit",Type=HX_PROPERTY_Int,LowerLimit="50",UpperLimit="999")
    Properties(2)=(Name="ProjectileCompensationLimit",Type=HX_PROPERTY_Int,LowerLimit="50",UpperLimit="999")
    Properties(3)=(Name="MaxCollisionCheckRate",Type=HX_PROPERTY_Int,LowerLimit="25",UpperLimit="100")
    Properties(4)=(Name="bBoostedAimSynchronization",Type=HX_PROPERTY_Bool)
    Properties(5)=(Name="bForceStartFireRPCs",Type=HX_PROPERTY_Bool)
    Properties(6)=(Name="bClientSideCollisions",Type=HX_PROPERTY_Bool)
    Properties(7)=(Name="CSCTolerance",Type=HX_PROPERTY_Int,LowerLimit="1",UpperLimit="10")
    Properties(8)=(Name="bRubberbandingFix",Type=HX_PROPERTY_Bool)
    Properties(9)=(Name="bLinkMeshes",Type=HX_PROPERTY_Bool)
    DisplayInfo(0)=(Section="General",Caption="Ping Frequency",Hint="Frequency to send ping packets (pings/second). Lower this value if server connection is saturated.",Step="0.25",bMPOnly=true,bAdvanced=true,Verbosity=HX_VERB_Medium)
    DisplayInfo(1)=(Section="General",Caption="Lag Compensation Limit",Hint="Global lag compensation limit (in milliseconds).",Step="10",bMPOnly=true,bAdvanced=true,Verbosity=HX_VERB_Medium)
    DisplayInfo(2)=(Section="Projectiles",Caption="Projectile Compensation Limit",Hint="Projectile-specific lag compensation limit (in milliseconds).",Step="10",bMPOnly=true,bAdvanced=true,Verbosity=HX_VERB_Medium)
    DisplayInfo(3)=(Section="Projectiles",Caption="Max. Collision Check Rate",Hint="Maximum rate to check for projectile collisions during server-side forwarding. The actual rate is the minimum between this value and the server's tick rate.",Step="5",bMPOnly=true,bAdvanced=true,Verbosity=HX_VERB_Medium)
    DisplayInfo(4)=(Section="Boosted Aim Synchronization (BAS)",Caption="Enable BAS",Hint="When triggering a shot, send the client's location and camera rotation to the server to synchronize the aim. Applied on restart/map change.",bMPOnly=true,bAdvanced=true,Verbosity=HX_VERB_Medium)
    DisplayInfo(5)=(Section="Boosted Aim Synchronization (BAS)",Caption="Force Start Fire RPCs",Hint="Force a new start fire RPC for every shot while holding the fire button. If disabled, BAS is only applied to the first shot while holding fire.",Dependency="bBoostedAimSynchronization",bMPOnly=true,bAdvanced=true,Verbosity=HX_VERB_Medium)
    DisplayInfo(6)=(Section="Boosted Aim Synchronization (BAS)",Caption="Evaluate Client-Side Collisions",Hint="Execute client-side collision detection and add the result to BAS. The server decides if the collision is valid. Only applies to hitscan weapons.",Dependency="bBoostedAimSynchronization",bMPOnly=true,bAdvanced=true,Verbosity=HX_VERB_Medium)
    DisplayInfo(7)=(Section="Boosted Aim Synchronization (BAS)",Caption="Client-Side Collision Tolerance",Hint="Maximum acceptable temporal distance to validate client-side collisions, expressed in server ticks.",Step="1",Dependency="bBoostedAimSynchronization",bMPOnly=true,bAdvanced=true,Verbosity=HX_VERB_Medium)
    DisplayInfo(8)=(Section="Miscellaneous",Caption="Backport Rubberbanding Fix",Hint="Backport OldUnreal's rubberbanding fix. Applied on restart/map change.",bMPOnly=true,bAdvanced=true,Verbosity=HX_VERB_Medium)
    DisplayInfo(9)=(Section="Miscellaneous",Caption="Link Meshes",Hint="Link meshes for collision detection. Disable this if experiencing crashes.",bMPOnly=true,bAdvanced=true,Verbosity=HX_VERB_Medium)
    ConfigClasses(0)=class'HxNetcodeConfig'
    Priority=64
    ClassOverrides(0)=(TargetClass=class'AssaultRifle',NETClass=class'HxNet_AssaultRifle',FireModeOverrides=((TargetClass=class'AssaultFire',NETClass=class'HxNet_AssaultFire'),(TargetClass=class'AssaultGrenade',NETClass=class'HxNet_AssaultGrenade')))
    ClassOverrides(1)=(TargetClass=class'BioRifle',NETClass=class'HxNet_BioRifle',FireModeOverrides=((TargetClass=class'BioFire',NETClass=class'HxNet_BioFire'),(TargetClass=class'BioChargedFire',NETClass=class'HxNet_BioChargedFire')))
    ClassOverrides(2)=(TargetClass=class'ShockRifle',NETClass=class'HxNet_ShockRifle',FireModeOverrides=((TargetClass=class'ShockBeamFire',NETClass=class'HxNet_ShockBeamFire'),(TargetClass=class'ShockProjFire',NETClass=class'HxNet_ShockProjFire')))
    ClassOverrides(3)=(TargetClass=class'LinkGun',NETClass=class'HxNet_LinkGun',FireModeOverrides=((TargetClass=class'LinkAltFire',NETClass=class'HxNet_LinkAltFire'),(TargetClass=class'LinkFire',NETClass=class'HxNet_LinkFire')))
    ClassOverrides(4)=(TargetClass=class'MiniGun',FireModeOverrides=((TargetClass=class'MiniGunFire',NETClass=class'HxNet_MiniGunFire'),(TargetClass=class'MiniGunAltFire',NETClass=class'HxNet_MiniGunAltFire')))
    ClassOverrides(5)=(TargetClass=class'FlakCannon',NETClass=class'HxNet_FlakCannon',FireModeOverrides=((TargetClass=class'FlakFire',NETClass=class'HxNet_FlakFire'),(TargetClass=class'FlakAltFire',NETClass=class'HxNet_FlakAltFire')))
    ClassOverrides(6)=(TargetClass=class'RocketLauncher',NETClass=class'HxNet_RocketLauncher',FireModeOverrides=((TargetClass=class'RocketFire',NETClass=class'HxNet_RocketFire'),(TargetClass=class'RocketMultiFire',NETClass=class'HxNet_RocketMultiFire')))
    ClassOverrides(7)=(TargetClass=class'SniperRifle',NETClass=class'HxNet_SniperRifle',FireModeOverrides=((TargetClass=class'SniperFire',NETClass=class'HxNet_SniperFire')))
    ClassOverrides(8)=(TargetClass=class'ClassicSniperRifle',NETClass=class'HxNet_ClassicSniperRifle',FireModeOverrides=((TargetClass=class'ClassicSniperFire',NETClass=class'HxNet_ClassicSniperFire')))
    ClassOverrides(9)=(TargetClass=class'SuperShockRifle',NETClass=class'HxNet_SuperShockRifle',FireModeOverrides=((TargetClass=class'SuperShockBeamFire',NETClass=class'HxNet_SuperShockBeamFire'),(TargetClass=class'SuperShockBeamFire',NETClass=class'HxNet_SuperShockBeamFire')))
    ClassOverrides(10)=(TargetClass=class'ZoomSuperShockRifle',NETClass=class'HxNet_ZoomSuperShockRifle',FireModeOverrides=((TargetClass=class'ZoomSuperShockBeamFire',NETClass=class'HxNet_ZoomSuperShockBeamFire')))
    ClassOverrides(11)=(TargetClass=class'HxSuperShockRifle',NETClass=class'HxNet_HxSuperShockRifle',FireModeOverrides=((TargetClass=class'SuperShockBeamFire',NETClass=class'HxNet_SuperShockBeamFire'),(TargetClass=class'SuperShockBeamFire',NETClass=class'HxNet_SuperShockBeamFire')))
    ClassOverrides(12)=(TargetClass=class'HxZoomSuperShockRifle',NETClass=class'HxNet_HxZoomSuperShockRifle',FireModeOverrides=((TargetClass=class'ZoomSuperShockBeamFire',NETClass=class'HxNet_ZoomSuperShockBeamFire')))
    PingFrequency=2.0
    LagCompensationLimit=300
    ProjectileCompensationLimit=125
    MaxCollisionCheckRate=50
    bBoostedAimSynchronization=true
    bForceStartFireRPCs=true
    bClientSideCollisions=true
    CSCTolerance=2
    bRubberbandingFix=false
    bLinkMeshes=true
}
