class HxNTClient extends HxClientReplicationInfo;

struct HxRandomRotator
{
    var int Pitch;
    var int Yaw;
};

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
var private HxRandomRotator RandomRotators[32];
var private int NextRandomRotator;
var private Vector RandomVectors[16];
var private int NextRandomVector;
var private float RandomFloats[128];
var private int NextRandomFloat;
var private HxDummyGroup DummyGroups[WEAPON_GROUP_COUNT];

replication
{
    reliable if (Role == ROLE_Authority)
        RandomRotators, RandomVectors, RandomFloats;

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
    PopulateRandomRotators();
    PopulateRandomVectors();
    PopulateRandomFloats();
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

function ServerPing(float Timestamp, float ClientAverageDeltaTime)
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
    local int GroupIndex;
    local int WeaponIndex;
    local int Index;

    GroupIndex = WeaponClass.default.InventoryGroup;
    WeaponIndex = FindWeaponIndex(WeaponClass, GroupIndex);
    Index = DummyGroups[GroupIndex].Weapons[WeaponIndex].Dummies.Length;
    DummyGroups[GroupIndex].Weapons[WeaponIndex].Dummies.Insert(Index, 1);
    DummyGroups[GroupIndex].Weapons[WeaponIndex].Dummies[Index] = Dummy;
}

simulated function DestroyDummyProjectile(class<Weapon> WeaponClass, int Index)
{
    local int GroupIndex;
    local int WeaponIndex;
    local int i;

    GroupIndex = WeaponClass.default.InventoryGroup;
    WeaponIndex = FindWeaponIndex(WeaponClass, GroupIndex);
    DummyGroups[GroupIndex].Weapons[WeaponIndex].Dummies[Index].Destroy();
    DummyGroups[GroupIndex].Weapons[WeaponIndex].Dummies.Remove(Index, 1);
    for (i = DummyGroups[GroupIndex].Weapons[WeaponIndex].Dummies.Length - 1; i >= 0; --i)
    {
        if (DummyGroups[GroupIndex].Weapons[WeaponIndex].Dummies[i] == None)
        {
            DummyGroups[GroupIndex].Weapons[WeaponIndex].Dummies.Remove(i, 1);
        }
    }
}

simulated function array<Projectile> GetDummies(class<Weapon> WeaponClass)
{
    local int GroupIndex;
    local int WeaponIndex;

    GroupIndex = WeaponClass.default.InventoryGroup;
    WeaponIndex = FindWeaponIndex(WeaponClass, GroupIndex);
    return DummyGroups[GroupIndex].Weapons[WeaponIndex].Dummies;
}

simulated function int FindWeaponIndex(class<Weapon> WeaponClass, int GroupIndex)
{
    local int i;

    for (i = 0; i < DummyGroups[GroupIndex].Weapons.Length; ++i)
    {
        if (DummyGroups[GroupIndex].Weapons[i].WeaponClass == WeaponClass)
        {
            return i;
        }
    }
    DummyGroups[GroupIndex].Weapons.Insert(i, 1);
    DummyGroups[GroupIndex].Weapons[i].WeaponClass = WeaponClass;
    return i;
}

function PopulateRandomRotators()
{
    local Rotator RandomRotator;
    local HxRandomRotator NewRotator;
    local int i;

    for (i = 0; i < ArrayCount(RandomRotators); ++i)
    {
        RandomRotator = RotRand();
        NewRotator.Pitch = RandomRotator.Pitch;
        NewRotator.Yaw = RandomRotator.Yaw;
        RandomRotators[i] = NewRotator;
    }
}

function ReplaceRandomRotator()
{
    local Rotator RandomRotator;
    local HxRandomRotator Replacement;

    RandomRotator = RotRand();
    Replacement.Pitch = RandomRotator.Pitch;
    Replacement.Yaw = RandomRotator.Yaw;
    RandomRotators[NextRandomRotator] = Replacement;
}

simulated function Rotator GetRandomRotator()
{
    local Rotator Result;

    Result.Pitch = RandomRotators[NextRandomRotator].Pitch;
    Result.Yaw = RandomRotators[NextRandomRotator].Yaw;
    ReplaceRandomRotator();
    NextRandomRotator = (NextRandomRotator + 1) % ArrayCount(RandomRotators);
    return Result;
}

function PopulateRandomVectors()
{
    local int i;

    for (i = 0; i < ArrayCount(RandomVectors); ++i)
    {
        RandomVectors[i] = VRand();
    }
}

function ReplaceRandomVector()
{
    RandomVectors[NextRandomVector] = VRand();
}

simulated function Vector GetRandomVector()
{
    local Vector Result;

    Result = RandomVectors[NextRandomVector];
    ReplaceRandomVector();
    NextRandomVector = (NextRandomVector + 1) % ArrayCount(RandomVectors);
    return Result;
}

function PopulateRandomFloats()
{
    local int i;

    for (i = 0; i < ArrayCount(RandomFloats); ++i)
    {
        RandomFloats[i] = FRand();
    }
}

function ReplaceRandomFloat()
{
    RandomFLoats[NextRandomFloat] = FRand();
}

simulated function float GetRandomFloat()
{
    local float Result;

    Result = RandomFLoats[NextRandomFloat];
    ReplaceRandomFloat();
    NextRandomFloat = (NextRandomFloat + 1) % ArrayCount(RandomFLoats);
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
