class HxNTClient extends HxClientReplicationInfo;

struct HxWeaponDummies
{
    var class<Weapon> WeaponClass;
    var array<Projectile> Dummies;
};

struct HxDummyGroup
{
    var array<HxWeaponDummies> Weapons;
};

// BallLauncher's InventoryGroup is 15
const WEAPON_GROUP_COUNT = 16;
const WARMUP_COUNT = 10;

var float AveragePing;
var float AverageDeltaTime;
var float ProjectileCompensationLimit;

var private HxNetcodeConfig NetConfig;
var private FakeProjectileManager FPM;
var private int PingCount;
var private int TickCount;
var private bool bEnhancedNetcode;
var private float PingInterval;
var private float PingSmoothing;
var private bool bClientUpdated;
var private float ServerUpdateRequested[3];
// TODO: maybe change to native vector to preserve bandwidth?
var private HxTypes.HxVector RandomVectors[16];
var private int LGRandomVectorIndex;
var private HxDummyGroup DummyGroups[WEAPON_GROUP_COUNT];

replication
{
    reliable if (Role == ROLE_Authority)
        RandomVectors;

    unreliable if (Role == ROLE_Authority)
        ClientRequestPing,
        ClientUpdatePing;

    reliable if (Role == ROLE_Authority)
        ClientSetAllowMultiHit;

    unreliable if (Role < ROLE_Authority)
        ServerPing;

    reliable if (Role < ROLE_Authority)
        ServerSetEnhancedNetcode,
        ServerSetPingFrequency,
        ServerSetPingSmoothingFactor;
}

simulated event PostBeginPlay()
{
    Super.PostBeginPlay();
    PopulateRandomVectors();
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
    bEnhancedNetcode = NetConfig.bEnhancedNetcode && Level.NetMode != NM_ListenServer;
    if (Level.NetMode == NM_Client)
    {
        ServerSetPingSmoothingFactor(NetConfig.PingSmoothing);
        ServerSetPingFrequency(NetConfig.PingFrequency);
        ServerSetEnhancedNetcode(bEnhancedNetcode);
    }
}

simulated function ClientRequestPing(float Timestamp)
{
    ServerPing(Timestamp);
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
        if (ServerUpdateRequested[0] > 0
            && Level.TimeSeconds - ServerUpdateRequested[0] > Level.TimeDilation)
        {
            ServerSetEnhancedNetcode(bEnhancedNetcode);
            ServerUpdateRequested[0] = 0;
        }
        if (ServerUpdateRequested[1] > 0
            && Level.TimeSeconds - ServerUpdateRequested[1] > Level.TimeDilation)
        {
            ServerSetPingFrequency(NetConfig.PingFrequency);
            ServerUpdateRequested[1] = 0;
        }
        if (ServerUpdateRequested[2] > 0
            && Level.TimeSeconds - ServerUpdateRequested[2] > Level.TimeDilation)
        {
            ServerSetPingSmoothingFactor(NetConfig.PingSmoothing);
            ServerUpdateRequested[2] = 0;
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

function ServerPing(float Timestamp)
{
    local float NewPing;

    NewPing = Level.TimeSeconds - Timestamp;
    if (PingCount < WARMUP_COUNT)
    {
        PingCount++;
        AveragePing += (NewPing - AveragePing) / PingCount;
    }
    else
    {
        AveragePing += (NewPing - AveragePing) * PingSmoothing;
    }
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
    ProjectileCompensationLimit = Value / 1000;
}

function ServerSetEnhancedNetcode(bool bEnable)
{
    bEnhancedNetcode = bEnable;
    if (!bEnable)
    {
        Disable('Timer');
    }
    else
    {
        Enable('Timer');
        SetTimer(PingInterval, true);
    }
}

function ServerSetPingFrequency(float Frequency)
{
    Frequency = FClamp(
        Frequency,
        float(ConfigClasses[0].default.Properties[1].LowerLimit),
        MutHexedNET(MutatorOwner).MaxPingFrequency);
    PingInterval = Level.TimeDilation / Frequency;
    if (bEnhancedNetcode)
    {
        SetTimer(PingInterval, true);
    }
}

function ServerSetPingSmoothingFactor(float Factor)
{
    PingSmoothing = FClamp(
        Factor, float(ConfigClasses[0].default.Properties[2].LowerLimit), 1.0);
}

simulated function NotifyServerPropertiesReady()
{
    FPM = FakeProjectileManager(SpawnUnique(Class'FakeProjectileManager', Self));
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
        case "bEnhancedNetcode":
            bEnhancedNetcode = NetConfig.bEnhancedNetcode && Level.NetMode != NM_ListenServer;
            break;
    }
    if (ServerUpdateRequested[Index] == 0)
    {
        ServerUpdateRequested[Index] = Level.TimeSeconds;
    }
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

simulated function bool IsEnhancedNetcodeEnabled()
{
    return bEnhancedNetcode && AveragePing > 0;
}

simulated function bool ShouldSpawnDummyProjectile()
{
    return AveragePing > (AverageDeltaTime * 1.5);
}

simulated function TrackDummyProjectile(Projectile Dummy, class<Weapon> WeaponClass)
{
    local int Weapon;
    local int Index;

    Weapon = FindWeaponIndex(WeaponClass);
    Index = DummyGroups[WeaponClass.default.InventoryGroup].Weapons[Weapon].Dummies.Length;
    DummyGroups[WeaponClass.default.InventoryGroup].Weapons[Weapon].Dummies.Insert(Index, 1);
    DummyGroups[WeaponClass.default.InventoryGroup].Weapons[Weapon].Dummies[Index] = Dummy;
}

simulated function UntrackDummyProjectile(class<Weapon> WeaponClass, int Index)
{
    local int WeaponIndex;

    WeaponIndex = FindWeaponIndex(WeaponClass);
    DummyGroups[WeaponClass.default.InventoryGroup].Weapons[WeaponIndex].Dummies[Index].Destroy();
    DummyGroups[WeaponClass.default.InventoryGroup].Weapons[WeaponIndex].Dummies.Remove(Index, 1);
}

simulated function array<Projectile> GetDummies(class<Weapon> WeaponClass)
{
    local int WeaponIndex;

    WeaponIndex = FindWeaponIndex(WeaponClass);
    return DummyGroups[WeaponClass.default.InventoryGroup].Weapons[WeaponIndex].Dummies;
}

simulated function int FindWeaponIndex(class<Weapon> WeaponClass)
{
    local int i;

    for (i = 0; i < DummyGroups[WeaponClass.default.InventoryGroup].Weapons.Length; ++i)
    {
        if (DummyGroups[WeaponClass.default.InventoryGroup].Weapons[i].WeaponClass == WeaponClass)
        {
            return i;
        }
    }
    DummyGroups[WeaponClass.default.InventoryGroup].Weapons.Insert(i, 1);
    DummyGroups[WeaponClass.default.InventoryGroup].Weapons[i].WeaponClass = WeaponClass;
    return i;
}

function PopulateRandomVectors()
{
    local vector RandomVector;
    local int i;

    for (i = 0; i < ArrayCount(RandomVectors); ++i)
    {
        RandomVector = VRand();
        RandomVectors[i].X = RandomVector.X;
        RandomVectors[i].Y = RandomVector.Y;
        RandomVectors[i].Z = RandomVector.Z;
    }
}

function ReplaceRandomVector()
{
    local vector RandomVector;
    local HxTypes.HxVector Replacement;

    RandomVector = VRand();
    Replacement.X = RandomVector.X;
    Replacement.Y = RandomVector.Y;
    Replacement.Z = RandomVector.Z;
    RandomVectors[LGRandomVectorIndex] = Replacement;
}

simulated function vector GetRandomVector()
{
    local vector Result;

    Result.X = RandomVectors[LGRandomVectorIndex].X;
    Result.Y = RandomVectors[LGRandomVectorIndex].Y;
    Result.Z = RandomVectors[LGRandomVectorIndex].Z;
    ReplaceRandomVector();
    LGRandomVectorIndex = (LGRandomVectorIndex + 1) % ArrayCount(RandomVectors);
    return Result;
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
