class HxNTClient extends HxClientReplicationInfo;

const PING_WARMUP_COUNT = 10;

var float AveragePing;
var float ProjectileCompensationLimit;

var private HxNetcodeConfig NetConfig;
var private FakeProjectileManager FPM;
var private int PingCount;
var private bool bEnhancedNetcode;
var private float PingInterval;
var private float PingSmoothing;
var private bool bClientUpdated;
var private array<float> ServerUpdateRequested;

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
        ServerSetEnhancedNetcode,
        ServerSetPingFrequency,
        ServerSetPingSmoothingFactor;
}

simulated event PostBeginPlay()
{
    Super.PostBeginPlay();
    if (Level.NetMode != NM_DedicatedServer)
    {
        NetConfig = HxNetcodeConfig(Configs[0]);
        ServerUpdateRequested.Length = NetConfig.Properties.Length;
        bEnhancedNetcode = NetConfig.bEnhancedNetcode && Level.NetMode != NM_ListenServer;
    }
}

simulated event PostNetBeginPlay()
{
    Super.PostNetBeginPlay();
    if (Level.NetMode == NM_Client)
    {
        ServerSetPingSmoothingFactor(NetConfig.PingSmoothing);
        ServerSetPingFrequency(NetConfig.PingFrequency);
        ServerSetEnhancedNetcode(bEnhancedNetcode);
    }
}

function SetupServer(HxMutator Mutator)
{
    Super.SetupServer(Mutator);
    SetProjectileCompensationLimit(GetServerProperty("ProjectileCompensationLimit"));
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

    PingCount++;
    NewPing = Level.TimeSeconds - Timestamp;
    if (PingCount < PING_WARMUP_COUNT)
    {
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
    class'NewNet_ZoomSuperShockBeamFire'.default.bServerAllowMultiHit = bEnable;
}

simulated function float GetProjectilePing()
{
    return FMin(AveragePing, ProjectileCompensationLimit);
}

simulated function bool IsEnhancedNetcodeEnabled()
{
    return bEnhancedNetcode;
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
    NetUpdateFrequency=10
    NetPriority=3

    MutatorClass=class'MutHexedNET'
    ConfigClasses(0)=class'HxNetcodeConfig'
    Order=64
    PingInterval=0.7
    PingSmoothing=0.3
}
