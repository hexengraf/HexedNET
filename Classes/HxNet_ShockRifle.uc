class HxNet_ShockRifle extends ShockRifle
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
            Self, class'ShockRifle', !default.bConfigCleared);
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

    if (!class'HxNTWeapon'.static.DoBAS(Self)
        || !class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        || !Client.WantsPingCompensation())
    {
        Super.ClientStartFire(Mode);
    }
    else if (StartFire(Mode))
    {
        if (HxNet_ShockBeamFire(FireMode[Mode]) != None)
        {
            BAS = class'HxNTWeapon'.static.EncodeBAS(Self, Mode, true);
            HxNet_ShockBeamFire(FireMode[Mode]).ApplyBAS(BAS);
        }
        else if (HxNet_ShockProjFire(FireMode[Mode]) != None)
        {
            BAS = class'HxNTWeapon'.static.EncodeBAS(Self, Mode);
            HxNet_ShockProjFire(FireMode[Mode]).ApplyBAS(BAS);
        }
        ServerStartFireBAS(Mode, BAS);
        StopFireTime[Mode] = 3;
    }
}

function ServerStartFireBAS(byte Mode, HxNTWeapon.HxBAS BAS)
{
    if (HxNet_ShockBeamFire(FireMode[Mode]) != None)
    {
        HxNet_ShockBeamFire(FireMode[Mode]).ApplyBAS(BAS);
    }
    else if (HxNet_ShockProjFire(FireMode[Mode]) != None)
    {
        HxNet_ShockProjFire(FireMode[Mode]).ApplyBAS(BAS);
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
            FireMode[Mode].NextFireTime -= ServerDelay + 0.001;
            if (HxNet_ShockBeamFire(FireMode[Mode]) != None)
            {
                HxNet_ShockBeamFire(FireMode[Mode]).ServerDelay = ServerDelay;
            }
            else if (HxNet_ShockProjFire(FireMode[Mode]) != None)
            {
                HxNet_ShockProjFire(FireMode[Mode]).ServerDelay = ServerDelay;
            }
        }
        return true;
    }
    return false;
}

defaultproperties
{
    FireModeClass(0)=class'HxNet_ShockBeamFire'
    FireModeClass(1)=class'HxNet_ShockProjFire'
}
