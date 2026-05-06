class HxNTClient extends HxClientReplicationInfo
    config(User);

const PING_WARMUP_COUNT = 10;
const PING_SMOOTHING = 0.3;

var float AveragePing;

var private HxNetcodeConfig Config;
var private FakeProjectileManager FPM;
var private int PingCount;
var private bool bEnhancedNetcode;
var private bool bClientUpdated;

replication
{
    reliable if (Role == ROLE_Authority)
        ClientRequestPing,
        ClientUpdatePing,
        ClientSetAllowMultiHit;

    reliable if (Role < ROLE_Authority)
        ServerPing,
        ServerSetEnhancedNetcode;
}

simulated event PreBeginPlay()
{
    Super.PreBeginPlay();
    if (Level.NetMode != NM_DedicatedServer)
    {
        Config = HxNetcodeConfig(Configs[0]);
        bEnhancedNetcode = Config.bEnhancedNetcode && Level.NetMode != NM_ListenServer;
    }
}

simulated event PostNetBeginPlay()
{
    Super.PostNetBeginPlay();
    if (Level.NetMode == NM_Client)
    {
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
        if (PlayerController(Owner) != None)
        {
            FixWeaponInstigator(PlayerController(Owner));
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
        AveragePing += (NewPing - AveragePing) * PING_SMOOTHING;
    }
    ClientUpdatePing(AveragePing);
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
        SetTimer(Level.TimeDilation / float(GetServerProperty("PingFrequency")), true);
    }
}

function SetServerProperty(int Index, string Value)
{
    Super.SetServerProperty(Index, Value);
    if (bEnhancedNetcode)
    {
        SetTimer(Level.TimeDilation / float(GetServerProperty("PingFrequency")), true);
    }
}

simulated function ServerInfoReady()
{
    FPM = Spawn(Class'FakeProjectileManager', Self);
}

simulated function bool SetConfigProperty(int ConfigIndex, int PropertyIndex, string Value)
{
    if (Super.SetConfigProperty(ConfigIndex, PropertyIndex, Value))
    {
        if (PropertyIndex == 0)
        {
            bEnhancedNetcode = Config.bEnhancedNetcode && Level.NetMode != NM_ListenServer;
            ServerSetEnhancedNetcode(bEnhancedNetcode);
        }
        return true;
    }
    return false;
}

simulated function ClientSetAllowMultiHit(bool bEnable)
{
    class'NewNet_ZoomSuperShockBeamFire'.default.bServerAllowMultiHit = bEnable;
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
}
