class HxNTClient extends HxClientReplicationInfo;

struct HxWeaponGroup
{
    var array<HxNTWeaponInfo> Weapons;
};

// BallLauncher's InventoryGroup is 15
const WEAPON_GROUP_COUNT = 16;
const WARMUP_COUNT = 10;
const BAS_LOCATION_TOLERANCE = 360;
const BAS_ANGLE_TOLERANCE = -0.5;

var float AveragePing;
var float AverageDeltaTime;
var float ProjectileCompensationLimit;

var private HxNetcodeConfig NetConfig;
var private int PingCount;
var private int TickCount;
var private bool bPingCompensation;
var private float PingInterval;
var private float PingSmoothing;
var private bool bClientUpdated;
var private HxWeaponGroup Groups[WEAPON_GROUP_COUNT];
var private HxRandomGeneratorAlt Seeder;

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
    SetProjectileCompensationLimit(GetServerProperty("ProjectileCompensationLimit"));
}

simulated function SetupClient(HxClientManager Manager)
{
    Super.SetupClient(Manager);
    NetConfig = HxNetcodeConfig(Configs[0]);
    if (Level.NetMode == NM_Client)
    {
        ServerSetPingSmoothing(NetConfig.PingSmoothing);
        ServerSetPingFrequency(NetConfig.PingFrequency);
        UpdatePingCompensation();
    }
    if (Manager.IsFirstRun())
    {
        // TODO: remove this in v11
        NetConfig.ClearConfig();
        NetConfig.SaveConfig();
    }
}

simulated function ClientRequestPing(float Timestamp)
{
    ServerPing(Timestamp, AverageDeltaTime);
}

simulated function ClientUpdatePing(float Ping)
{
    AveragePing = Ping;
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
            TickCount++;
            AverageDeltaTime += (DeltaTime - AverageDeltaTime) / TickCount;
        }
        else
        {
            AverageDeltaTime += (DeltaTime - AverageDeltaTime) * 0.5;
        }
    }
    else if (Level.NetMode == NM_DedicatedServer && !bClientUpdated)
    {
        ClientSetAllowMultiHit(class'ZoomSuperShockBeamFire'.default.bAllowMultiHit);
    }
}

event Timer()
{
    ClientRequestPing(Level.TimeSeconds);
}

function ServerPing(float Timestamp, float ClientAverageDeltaTime)
{
    local float NewPing;

    NewPing = MutHexedNET(MutatorOwner).NormalizePing(Level.TimeSeconds - Timestamp);
    if (PingCount < WARMUP_COUNT)
    {
        PingCount++;
        AveragePing += (NewPing - AveragePing) / PingCount;
    }
    else
    {
        AveragePing += (NewPing - AveragePing) * PingSmoothing;
    }
    AverageDeltaTime = ClientAverageDeltaTime;
    ClientUpdatePing(AveragePing);
}

function SetServerProperty(int Index, string Value)
{
    Super.SetServerProperty(Index, Value);
    if (MutatorClass.default.Properties[Index].Name == "ProjectileCompensationLimit")
    {
        SetProjectileCompensationLimit(Value);
    }
}

simulated function SetProjectileCompensationLimit(coerce float Value)
{
    ProjectileCompensationLimit = Value / (Level.TimeDilation * 1000.0);
}

function ServerSetPingCompensation(bool bEnable, int Seed)
{
    bPingCompensation = bEnable;
    if (bEnable)
    {
        SetTimer(PingInterval, true);
        Seeder.SetSeed(Seed);
        RefreshSeeds();
    }
    else
    {
        SetTimer(0, false);
    }
}

function ServerSetPingFrequency(float Frequency)
{
    Frequency = FClamp(
        Frequency,
        float(ConfigClasses[0].default.Properties[1].LowerLimit),
        MutHexedNET(MutatorOwner).MaxPingFrequency);
    PingInterval = Level.TimeDilation / Frequency;
    if (bPingCompensation)
    {
        SetTimer(PingInterval, true);
    }
}

function ServerSetPingSmoothing(float Factor)
{
    PingSmoothing = FClamp(Factor, float(ConfigClasses[0].default.Properties[2].LowerLimit), 1.0);
}

simulated function NotifyServerPropertiesReady()
{
    SetProjectileCompensationLimit(GetServerProperty("ProjectileCompensationLimit"));
}

simulated function NotifyServerPropertyChanged(int Index, string OldValue)
{
    if (MutatorClass.default.Properties[Index].Name == "ProjectileCompensationLimit")
    {
        SetProjectileCompensationLimit(GetServerProperty("ProjectileCompensationLimit"));
    }
}

simulated function NotifyUserPropertyChanged(HxConfig Config, int Index, string OldValue)
{
    switch (Config.Properties[Index].Name)
    {
        case "bPingCompensation":
            UpdatePingCompensation();
            break;
        case "PingFrequency":
            ServerSetPingFrequency(NetConfig.PingFrequency);
            break;
        case "PingSmoothing":
            ServerSetPingSmoothing(NetConfig.PingSmoothing);
            break;
    }
}

simulated function UpdatePingCompensation()
{
    local int Seed;

    bPingCompensation = NetConfig.bPingCompensation && Level.NetMode != NM_ListenServer;
    if (bPingCompensation)
    {
        Seed = Rand(MaxInt);
        Seeder.SetSeed(Seed);
        RefreshSeeds();
    }
    ServerSetPingCompensation(bPingCompensation, Seed);
}

simulated function ClientSetAllowMultiHit(bool bEnable)
{
    class'HxNet_ZoomSuperShockBeamFire'.default.bServerAllowMultiHit = bEnable;
}

simulated function float GetProjectilePing()
{
    return FMin(AveragePing, ProjectileCompensationLimit);
}

simulated function float GetProjectileDelay()
{
    return AveragePing - ProjectileCompensationLimit;
}

simulated function bool WantsPingCompensation()
{
    return bPingCompensation && AveragePing > AverageDeltaTime;
}

simulated function bool ShouldSpawnPredictedProjectile()
{
    return AveragePing > (AverageDeltaTime * 1.5);
}

simulated function bool IsAcceptableBAS(Weapon W, Vector BASStart, Rotator BASAim)
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

simulated function HxNTWeaponInfo GetWeaponInfo(class<Weapon> WeaponClass)
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

simulated function RefreshSeeds()
{
    local int i;
    local int j;

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
    ConfigClasses(0)=class'HxNetcodeConfig'
    Order=64
    PingInterval=0.7
    PingSmoothing=0.3
}
