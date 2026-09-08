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

simulated event PreBeginPlay()
{
    Super.PreBeginPlay();
    if (Level.NetMode != NM_DedicatedServer)
    {
        class'HxNTWeapon'.static.LoadDefaultConfig(
            Self, class'SuperShockRifle', !default.bConfigCleared);
        default.bConfigCleared = true;
    }
}

simulated event PostBeginPlay()
{
    Super.PostBeginPlay();
    class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client);
}

simulated event WeaponTick(float DT)
{
    Super.WeaponTick(DT);
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

    if (!class'HxNTWeapon'.static.DoBAS(Self) || ShockBeamFire(FireMode[Mode]) == None
        || !class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        || !Client.WantsPingCompensation())
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
        if (FireMode[Mode].bServerDelayStartFire
            && HxNet_SuperShockBeamFire(FireMode[Mode]) != None)
        {
            FireMode[Mode].NextFireTime -= ServerDelay + 0.001;
            HxNet_SuperShockBeamFire(FireMode[Mode]).ServerDelay = ServerDelay;
        }
        return true;
    }
    return false;
}

defaultproperties
{
    FireModeClass(0)=class'HxNet_SuperShockBeamFire'
    FireModeClass(1)=class'HxNet_SuperShockBeamFire'
}
