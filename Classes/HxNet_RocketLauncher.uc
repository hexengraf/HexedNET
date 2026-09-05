class HxNet_RocketLauncher extends RocketLauncher
    DependsOn(HxNTWeapon)
    HideDropDown
    CacheExempt;

var private MutHexedNET HexedNET;
var private HxNTClient Client;
var private int StopFireTime[2];
var private bool bConfigCleared;
var private Pawn ClientSeekTarget;

replication
{
    reliable if (Role == ROLE_Authority && bNetOwner)
        ClientSeekTarget;

    reliable if (Role < Role_Authority)
        ServerStartFireBAS, ServerStopFireBAS;
}

simulated function PreBeginPlay()
{
    Super.PreBeginPlay();
    if (Level.NetMode != NM_DedicatedServer)
    {
        if (!default.bConfigCleared)
        {
            ClearConfig();
            default.bConfigCleared = true;
        }
        class'HxNTWeapon'.static.ForceBaseClassConfig(Self, class'RocketLauncher');
    }
}

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    if (Level.NetMode != NM_Client)
    {
        foreach DynamicActors(class'MutHexedNET', HexedNET) break;
    }
    else
    {
        class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client);
    }
}

simulated function bool IsEnhancedNetcodeEnabled()
{
    return class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        && Client.IsEnhancedNetcodeEnabled();
}

simulated event WeaponTick(float DT)
{
    Super.WeaponTick(DT);
    if (Role == ROLE_Authority)
    {
        ClientSeekTarget = SeekTarget;
    }
    else
    {
        SeekTarget = ClientSeekTarget;
    }
    class'HxNTWeapon'.static.CheckStopFire(Self, StopFireTime[0], StopFireTime[1]);
}

simulated event ClientStopFire(int Mode)
{
    local HxNTWeapon.HxBAS BAS;

    if (Role == ROLE_Authority || HxNet_RocketMultiFire(FireMode[Mode]) == None
        || !IsEnhancedNetcodeEnabled())
    {
        Super.ClientStopFire(Mode);
    }
    else
    {
        BAS = class'HxNTWeapon'.static.EncodeBAS(Self, Mode);
        HxNet_RocketMultiFire(FireMode[Mode]).ApplyBAS(BAS);
        StopFire(Mode);
        ServerStopFireBAS(Mode, BAS);
    }
    StopFireTime[Mode] = 0;
}

simulated event ClientStartFire(int Mode)
{
    local HxNTWeapon.HxBAS BAS;

    if (Role == ROLE_Authority || Pawn(Owner).Controller.IsInState('GameEnded')
        || Pawn(Owner).Controller.IsInState('RoundEnded')
        || HxNet_RocketFire(FireMode[Mode]) == None
        || !IsEnhancedNetcodeEnabled())
    {
        Super.ClientStartFire(Mode);
    }
    else if (StartFire(Mode))
    {
        BAS = class'HxNTWeapon'.static.EncodeBAS(Self, Mode);
        HxNet_RocketFire(FireMode[Mode]).ApplyBAS(BAS);
        ServerStartFireBAS(Mode, BAS);
        StopFireTime[Mode] = 3;
    }
}

function ServerStopFireBAS(byte Mode, HxNTWeapon.HxBAS BAS)
{
    if (HxNet_RocketMultiFire(FireMode[Mode]) != None)
    {
        HxNet_RocketMultiFire(FireMode[Mode]).ApplyBAS(BAS);
    }
    ServerStopFire(Mode);
}

function ServerStartFireBAS(byte Mode, HxNTWeapon.HxBAS BAS)
{
    if (HxNet_RocketFire(FireMode[Mode]) != None)
    {
        HxNet_RocketFire(FireMode[Mode]).ApplyBAS(BAS);
    }
    ServerStartFire(Mode);
}

simulated function bool StartFire(int Mode)
{
    local float ServerDelay;

    ServerDelay = Level.TimeSeconds - FireMode[Mode].NextFireTime;
    if (Super.StartFire(Mode))
    {
        if (FireMode[Mode].bServerDelayStartFire)
        {
            if (HxNet_RocketFire(FireMode[Mode]) != None)
            {
                FireMode[Mode].NextFireTime -= ServerDelay + 0.001;
                HxNet_RocketFire(FireMode[Mode]).ServerDelay = ServerDelay;
            }
        }
        return true;
    }
    return false;
}

static function RocketProj SpawnHexedProjectile(RocketLauncher Weapon,
                                                Vector Start,
                                                Rotator Dir,
                                                class<RocketProj> RocketClass,
                                                class<SeekingRocketProj> SeekingRocketClass)
{
    local SeekingRocketProj SeekingRocket;

    if (Weapon.bLockedOn && Weapon.SeekTarget != None)
    {
        SeekingRocket = Weapon.Spawn(SeekingRocketClass,,, Start, Dir);
        SeekingRocket.Seeking = Weapon.SeekTarget;
        return SeekingRocket;
    }
    return Weapon.Spawn(RocketClass,,, Start, Dir);
}

DefaultProperties
{
    FireModeClass(0)=class'HxNet_RocketFire'
    FireModeClass(1)=class'HxNet_RocketMultiFire'
}
