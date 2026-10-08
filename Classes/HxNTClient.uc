class HxNTClient extends HxClientReplicationInfo;

struct HxWeaponGroup
{
    var array<HxNTWeaponInfo> Weapons;
};

// BallLauncher's InventoryGroup is 15
const WEAPON_GROUP_COUNT = 16;
const WARMUP_COUNT = 10;
const IGNORE_COUNT = 3;
const PING_INTERVAL_VARIANCE = 0.1;
const BAS_LOCATION_TOLERANCE = 360;
const BAS_ANGLE_TOLERANCE = -0.5;
const RTT_TIME_CONSTANT = 8.0;
const DELTA_TIME_ALPHA = 0.05;

var bool bLagCompensation;

var private HxWeaponGroup Groups[WEAPON_GROUP_COUNT];
var private HxRandomGeneratorAlt Seeder;
var private bool bClientUpdated;
var private bool bReceivedPing;
var private int PingCount;
var private int TickCount;
var private float LatestTimestamp;
var private float AvgRTT;
var private float RTTAlpha;
var private float AvgDeltaTime;
var private float PingInterval;
var private float LagCompensationLimit;
var private float ProjectileCompensationLimit;

replication
{
    unreliable if (Role == ROLE_Authority)
        ClientPing;

    reliable if (Role == ROLE_Authority)
        ClientSetAllowMultiHit;

    unreliable if (Role < ROLE_Authority)
        ServerPing,
        ServerUpdateStats;

    reliable if (Role < ROLE_Authority)
        ServerSetLagCompensation;
}

simulated event PostBeginPlay()
{
    Super.PostBeginPlay();
    Seeder = HxRandomGeneratorAlt(Level.ObjectPool.AllocateObject(class'HxRandomGeneratorAlt'));
}

simulated function InitializeCompensation()
{
    local int Seed;

    bLagCompensation = default.bLagCompensation && Level.NetMode != NM_ListenServer;
    if (bLagCompensation)
    {
        Seed = Rand(MaxInt);
        RefreshSeeds(Seed);
        UpdatePingInterval();
    }
    ServerSetLagCompensation(bLagCompensation, Seed);
}


function SetupServer(HxMutator Mutator)
{
    Super.SetupServer(Mutator);
    SetLagCompensationLimit(MutHexedNET(Mutator).LagCompensationLimit);
    SetProjectileCompensationLimit(MutHexedNET(Mutator).ProjectileCompensationLimit);
}

simulated function Tick(float DeltaTime)
{
    local float NewRTT;

    Super.Tick(DeltaTime);
    if (Level.NetMode == NM_Client)
    {
        if (PlayerOwner != None)
        {
            FixWeaponInstigator(PlayerOwner);
        }
        if (bReceivedPing)
        {
            bReceivedPing = false;
            if (TickCount < WARMUP_COUNT)
            {
                ++TickCount;
                AvgDeltaTime = AvgDeltaTime + (DeltaTime - AvgDeltaTime) / TickCount;
            }
            else
            {
                AvgDeltaTime = AvgDeltaTime + (DeltaTime - AvgDeltaTime) * DELTA_TIME_ALPHA;
            }
            NewRTT = Level.TimeSeconds - LatestTimestamp - (AvgDeltaTime * 0.5);
            if (PingCount < WARMUP_COUNT)
            {
                if (PingCount < IGNORE_COUNT)
                {
                    ++PingCount;
                }
                else
                {
                    ++PingCount;
                    AvgRTT = AvgRTT + (NewRTT - AvgRTT) / (PingCount - IGNORE_COUNT);
                }
            }
            else
            {
                AvgRTT = AvgRTT + (NewRTT - AvgRTT) * RTTAlpha;
            }
            ServerUpdateStats(AvgRTT, AvgDeltaTime);
        }
    }
    else if (Level.NetMode == NM_DedicatedServer && !bClientUpdated)
    {
        ClientSetAllowMultiHit(class'ZoomSuperShockBeamFire'.default.bAllowMultiHit);
        bClientUpdated = true;
    }
}

simulated event Timer()
{
    if (bLagCompensation)
    {
        ServerPing(Level.TimeSeconds);
    }
    else
    {
        SetTimer(0.0, false);
    }
}

function ServerPing(float Timestamp)
{
    ClientPing(MutHexedNET(MutatorOwner).AdjustTimestamp(Timestamp));
}

simulated function ClientPing(float Timestamp)
{
    LatestTimestamp = Timestamp;
    bReceivedPing = true;
}

function ServerUpdateStats(float NewAvgRTT, float NewAvgDeltaTime)
{
    AvgRTT = NewAvgRTT;
    AvgDeltaTime = NewAvgDeltaTime;
}

simulated function UpdatePingInterval()
{
    PingInterval = Level.TimeDilation / float(MutatorInfo.Get("PingFrequency"));
    PingInterval = PingInterval + PingInterval * PING_INTERVAL_VARIANCE * (FRand() - 0.5);
    RTTAlpha = FClamp(PingInterval / RTT_TIME_CONSTANT, 0.005, 0.5);
    SetTimer(PingInterval, true);
}

simulated function SetLagCompensationLimit(coerce float Value)
{
    LagCompensationLimit = (Value * Level.TimeDilation) / 1000.0;
}

simulated function SetProjectileCompensationLimit(coerce float Value)
{
    ProjectileCompensationLimit = (Value * Level.TimeDilation) / 1000.0;
}

function ServerSetLagCompensation(bool bEnable, int Seed)
{
    bLagCompensation = bEnable;
    if (bLagCompensation)
    {
        RefreshSeeds(Seed);
    }
}

simulated function NotifyMutatorInfoReady()
{
    SetLagCompensationLimit(MutatorInfo.Get("LagCompensationLimit"));
    SetProjectileCompensationLimit(MutatorInfo.Get("ProjectileCompensationLimit"));
    InitializeCompensation();
}

simulated function NotifyMutatorPropertyChanged(int Index)
{
    switch (MutatorInfo.GetName(Index))
    {
        case "PingFrequency":
            UpdatePingInterval();
            break;
        case "LagCompensationLimit":
            SetLagCompensationLimit(MutatorInfo.Get("LagCompensationLimit"));
            break;
        case "ProjectileCompensationLimit":
            SetProjectileCompensationLimit(MutatorInfo.Get("ProjectileCompensationLimit"));
            break;

    }
}

simulated function ClientSetAllowMultiHit(bool bEnable)
{
    class'HxNet_ZoomSuperShockBeamFire'.default.bServerAllowMultiHit = bEnable;
}

simulated final function float GetAveragePing()
{
    return (FMax(0.0, AvgRTT) / Level.TimeDilation) * 1000;
}

simulated final function float GetCompensationTime()
{
    return FMin(AvgRTT, LagCompensationLimit);
}

simulated final function float GetProjectileCompensationTime()
{
    return FMin(AvgRTT, ProjectileCompensationLimit);
}

simulated final function float GetProjectileDelay()
{
    return AvgRTT - ProjectileCompensationLimit;
}

simulated final function bool WantsPingCompensation()
{
    return bLagCompensation && AvgRTT > (AvgDeltaTime * 1.2);
}

simulated final function bool IsAcceptableBAS(Weapon W, Vector BASStart, Rotator BASAim)
{
    local Vector Diff;

    if (Role == ROLE_Authority)
    {
        if (Pawn(W.Owner) == None)
        {
            return false;
        }
        Diff = BASStart - (W.Owner.Location + Pawn(W.Owner).EyePosition());
        return (Diff dot Diff) < BAS_LOCATION_TOLERANCE
            && (Vector(BasAim) dot Vector(W.Owner.Rotation) > BAS_ANGLE_TOLERANCE);
    }
    return true;
}

simulated final function HxNTWeaponInfo GetWeaponInfo(class<Weapon> WeaponClass)
{
    local int GroupIndex;
    local int i;

    GroupIndex = WeaponClass.default.InventoryGroup;
    for (i = 0; i < Groups[GroupIndex].Weapons.Length; ++i)
    {
        if (Groups[GroupIndex].Weapons[i].WeaponClass == WeaponClass)
        {
            return Groups[GroupIndex].Weapons[i];
        }
    }
    Groups[GroupIndex].Weapons.Insert(i, 1);
    Groups[GroupIndex].Weapons[i] = HxNTWeaponInfo(
        Level.ObjectPool.AllocateObject(class'HxNTWeaponInfo'));
    Groups[GroupIndex].Weapons[i].WeaponClass = WeaponClass;
    Groups[GroupIndex].Weapons[i].Generator = HxRandomGenerator(
        Level.ObjectPool.AllocateObject(class'HxRandomGenerator'));
    Groups[GroupIndex].Weapons[i].RefreshSeed(Seeder);
    return Groups[GroupIndex].Weapons[i];
}

simulated final function RefreshSeeds(int Seed)
{
    local int i;
    local int j;

    Seeder.SetSeed(Seed);
    for (i = 0; i < WEAPON_GROUP_COUNT; ++i)
    {
        for (j = 0; j < Groups[i].Weapons.Length; ++j)
        {
            Groups[i].Weapons[j].RefreshSeed(Seeder);
        }
    }
}

simulated event Destroyed()
{
    local int i;
    local int j;

    for (i = 0; i < WEAPON_GROUP_COUNT; ++i)
    {
        for (j = 0; j < Groups[i].Weapons.Length; ++j)
        {
            if (Groups[i].Weapons[j] != None)
            {
                if (Groups[i].Weapons[j].Generator != None)
                {
                    Level.ObjectPool.FreeObject(Groups[i].Weapons[j].Generator);
                }
                Level.ObjectPool.FreeObject(Groups[i].Weapons[j]);
            }
        }
    }
    Level.ObjectPool.FreeObject(Seeder);
    Super.Destroyed();
}

// TODO: do we really need this?
static function FixWeaponInstigator(PlayerController PC)
{
    // fix annoying bug where sometimes weapon instigator gets set to none
    // due to race condition in replication
    if (PC.Pawn != None && PC.Pawn.Weapon != None && PC.Pawn.Weapon.Instigator != PC.Pawn)
    {
        PC.Pawn.Weapon.Instigator = PC.Pawn;
    }
}

defaultproperties
{
    MutatorClass=class'MutHexedNET'
    NetUpdateFrequency=100
    NetPriority=3
}
