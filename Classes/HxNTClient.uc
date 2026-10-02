class HxNTClient extends HxClientReplicationInfo;

struct HxWeaponGroup
{
    var array<HxNTWeaponInfo> Weapons;
};

// BallLauncher's InventoryGroup is 15
const WEAPON_GROUP_COUNT = 16;
const WARMUP_COUNT = 10;
const PING_INTERVAL_VARIANCE = 0.1;
const BAS_LOCATION_TOLERANCE = 360;
const BAS_ANGLE_TOLERANCE = -0.5;
const AVG_DELTA_RATIO = 0.3;

var private HxWeaponGroup Groups[WEAPON_GROUP_COUNT];
var private HxRandomGeneratorAlt Seeder;
var private bool bLagCompensation;
var private bool bClientUpdated;
var private int PingCount;
var private int TickCount;
var private float AvgPing;
var private float AvgDeltaTime;
var private float PingInterval;
var private float PingSmoothing;
var private float ProjectileCompensationLimit;

replication
{
    unreliable if (Role == ROLE_Authority)
        ClientRequestPing,
        ClientUpdatePing;

    reliable if (Role == ROLE_Authority)
        ClientSetAllowMultiHit;

    unreliable if (Role < ROLE_Authority)
        ServerPing;

    reliable if (Role < ROLE_Authority)
        ServerSetPingCompensation,
        ServerSetPingFrequency,
        ServerSetPingSmoothing;
}

simulated event PostBeginPlay()
{
    Super.PostBeginPlay();
    Seeder = HxRandomGeneratorAlt(Level.ObjectPool.AllocateObject(class'HxRandomGeneratorAlt'));
}

function SetupServer(HxMutator Mutator)
{
    Super.SetupServer(Mutator);
    SetProjectileCompensationLimit(MutHexedNET(Mutator).ProjectileCompensationLimit);
}

simulated function ClientRequestPing(float Timestamp)
{
    ServerPing(Timestamp, AvgDeltaTime);
}

simulated function ClientUpdatePing(float Ping)
{
    AvgPing = Ping;
}

simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    if (Level.NetMode == NM_Client)
    {
        if (PlayerOwner != None)
        {
            FixWeaponInstigator(PlayerOwner);
        }
        if (TickCount < WARMUP_COUNT)
        {
            ++TickCount;
            AvgDeltaTime = AvgDeltaTime + (DeltaTime - AvgDeltaTime) / TickCount;
        }
        else
        {
            AvgDeltaTime = AvgDeltaTime + (DeltaTime - AvgDeltaTime) * AVG_DELTA_RATIO;
        }
    }
    else if (Level.NetMode == NM_DedicatedServer && !bClientUpdated)
    {
        ClientSetAllowMultiHit(class'ZoomSuperShockBeamFire'.default.bAllowMultiHit);
        bClientUpdated = true;
    }
}

event Timer()
{
    if (bLagCompensation)
    {
        ClientRequestPing(Level.TimeSeconds);
        SetTimer(GetPingInterval(), false);
    }
}

function ServerPing(float Timestamp, float ClientAvgDeltaTime)
{
    local float NewPing;

    NewPing = MutHexedNET(MutatorOwner).NormalizePing(Level.TimeSeconds - Timestamp);
    if (PingCount < WARMUP_COUNT)
    {
        ++PingCount;
        AvgPing = AvgPing + (NewPing - AvgPing) / PingCount;
    }
    else
    {
        AvgPing = AvgPing + (NewPing - AvgPing) * PingSmoothing;
    }
    AvgDeltaTime = ClientAvgDeltaTime;
    ClientUpdatePing(AvgPing);
}

simulated function SetProjectileCompensationLimit(coerce float Value)
{
    ProjectileCompensationLimit = Value / (Level.TimeDilation * 1000.0);
}

function ServerSetPingCompensation(bool bEnable, int Seed)
{
    bLagCompensation = bEnable;
    if (bEnable)
    {
        SetTimer(GetPingInterval(), false);
        RefreshSeeds(Seed);
    }
}

function ServerSetPingFrequency(float NewFrequency)
{
    NewFrequency = FMin(NewFrequency, MutHexedNET(MutatorOwner).MaxPingFrequency);
    PingInterval = Level.TimeDilation / NewFrequency;
}

function ServerSetPingSmoothing(float NewPingSmoothing)
{
    PingSmoothing = NewPingSmoothing;
}

simulated function NotifyMutatorInfoReady()
{
    local HxNetcodeConfig NetConfig;

    SetProjectileCompensationLimit(MutatorInfo.Get("ProjectileCompensationLimit"));
    NetConfig = HxNetcodeConfig(FindConfig(class'HxNetcodeConfig'));
    if (ClientManager.IsFirstRun())
    {
        // TODO: remove this in v11
        NetConfig.ClearConfig();
        NetConfig.SaveConfig();
    }
    ServerSetPingSmoothing(NetConfig.PingSmoothing);
    ServerSetPingFrequency(NetConfig.PingFrequency);
    UpdatePingCompensation(NetConfig.bLagCompensation);
}

simulated function NotifyMutatorPropertyChanged(int Index)
{
    if (MutatorInfo.GetName(Index) == "ProjectileCompensationLimit")
    {
        SetProjectileCompensationLimit(MutatorInfo.Get("ProjectileCompensationLimit"));
    }
}

simulated function UpdatePingCompensation(bool bCompensate)
{
    local int Seed;

    bLagCompensation = bCompensate && Level.NetMode != NM_ListenServer;
    if (bLagCompensation)
    {
        Seed = Rand(MaxInt);
        RefreshSeeds(Seed);
    }
    ServerSetPingCompensation(bLagCompensation, Seed);
}

simulated function ClientSetAllowMultiHit(bool bEnable)
{
    class'HxNet_ZoomSuperShockBeamFire'.default.bServerAllowMultiHit = bEnable;
}

simulated final function float GetCompensationTime()
{
    return AvgPing;
}

simulated final function float GetProjectileCompensationTime()
{
    return FMin(AvgPing, ProjectileCompensationLimit);
}

simulated final function float GetProjectileDelay()
{
    return AvgPing - ProjectileCompensationLimit;
}

simulated final function bool WantsPingCompensation()
{
    return bLagCompensation && AvgPing > AvgDeltaTime;
}

simulated final function bool ShouldSpawnPredictedProjectile()
{
    return AvgPing > (AvgDeltaTime * 1.5);
}

simulated final function float GetPingInterval()
{
    return PingInterval + PingInterval * PING_INTERVAL_VARIANCE * (FRand() - 0.5);
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
    NetUpdateFrequency=100
    NetPriority=3
    MutatorClass=class'MutHexedNET'
    PingInterval=0.7
    PingSmoothing=0.3
}
