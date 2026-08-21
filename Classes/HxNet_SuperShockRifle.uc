class HxNet_SuperShockRifle extends SuperShockRifle
    DependsOn(HxNTWeapon)
    HideDropDown
    CacheExempt;

var private MutHexedNET HexedNET;
var private HxNTClient Client;
var private int StopFireTime[2];
var private bool bConfigCleared;

replication
{
    reliable if (Role < ROLE_Authority)
        ServerStartFireBAS;
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
        class'HxNTWeapon'.static.ForceBaseClassConfig(Self, class'SuperShockRifle');
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

simulated event WeaponTick(float dt)
{
    Super.WeaponTick(dt);
    class'HxNTWeapon'.static.CheckStopFire(Self, StopFireTime[0], StopFireTime[1]);
}

simulated event ClientStopFire(int Mode)
{
    Super.ClientStopFire(Mode);
    StopFireTime[Mode] = 0;
}

simulated event ClientStartFire(int Mode)
{
    local HxNTWeapon.HxBAS BAS;

    if (Role == ROLE_Authority || Pawn(Owner).Controller.IsInState('GameEnded')
        || Pawn(Owner).Controller.IsInState('RoundEnded') || ShockBeamFire(FireMode[Mode]) == None
        || !class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        || !Client.IsEnhancedNetcodeEnabled())
    {
        Super.ClientStartFire(Mode);
    }
    else if (StartFire(Mode))
    {
        BAS = class'HxNTWeapon'.static.EncodeBAS(Self, Mode, true);
        HxNet_SuperShockBeamFire(FireMode[Mode]).ApplyBAS(BAS);
        ServerStartFireBAS(Mode, BAS);
        StopFireTime[Mode] = 3;
    }
}

function ServerStartFireBAS(byte Mode, HxNTWeapon.HxBAS BAS)
{
    HxNet_SuperShockBeamFire(FireMode[Mode]).ApplyBAS(BAS);
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
            FireMode[Mode].NextFireTime -= ServerDelay + 0.001;
            if (HxNet_SuperShockBeamFire(FireMode[Mode]) != None)
            {
                HxNet_SuperShockBeamFire(FireMode[Mode]).ServerDelay = ServerDelay;
            }
        }
        return true;
    }
    return false;
}

DefaultProperties
{
    FireModeClass(0)=class'HxNet_SuperShockBeamFire'
    FireModeClass(1)=class'HxNet_SuperShockBeamFire'
}
