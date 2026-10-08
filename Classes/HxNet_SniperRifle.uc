class HxNet_SniperRifle extends SniperRifle
    DependsOn(HxNTWeapon)
    HideDropDown
    CacheExempt;

var private int StopFireTime[2];
var private bool bConfigCleared;

replication
{
    reliable if (Role < Role_Authority)
        ServerStartFireBAS;
}

simulated event PreBeginPlay()
{
    Super.PreBeginPlay();
    if (Level.NetMode != NM_DedicatedServer)
    {
        class'HxNTWeapon'.static.LoadDefaultConfig(
            Self, class'SniperRifle', !default.bConfigCleared);
        default.bConfigCleared = true;
    }
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

    if (Pawn(Owner).Controller.IsInState('GameEnded')
        || Pawn(Owner).Controller.IsInState('RoundEnded'))
    {
        return;
    }
    if (Role < ROLE_Authority && WantsStartFireBAS(Mode))
    {
        if (StartFire(Mode))
        {
            BAS = class'HxNTWeapon'.static.EncodeBAS(Self, Mode, true);
            HxNet_SniperFire(FireMode[Mode]).ApplyBAS(BAS);
            ServerStartFireBAS(Mode, BAS);
            StopFireTime[Mode] = 2;
        }
    }
    else
    {
        Super.ClientStartFire(Mode);
    }
}

function ServerStartFireBAS(byte Mode, HxNTWeapon.HxBAS BAS)
{
    HxNet_SniperFire(FireMode[Mode]).ApplyBAS(BAS);
    ServerStartFire(Mode);
}

simulated function bool StartFire(int Mode)
{
    local float ServerDelay;

    ServerDelay = Level.TimeSeconds - FireMode[Mode].NextFireTime;
    if (Super.StartFire(Mode))
    {
        if (FireMode[Mode].bServerDelayStartFire && HxNet_SniperFire(FireMode[Mode]) != None)
        {
            FireMode[Mode].NextFireTime -= ServerDelay + 0.001;
            HxNet_SniperFire(FireMode[Mode]).ServerDelay = ServerDelay;
        }
        return true;
    }
    return false;
}

simulated function bool WantsStartFireBAS(int Mode)
{
    return HxNet_SniperFire(FireMode[Mode]) != None
        && HxNet_SniperFire(FireMode[Mode]).WantsPingCompensation();
}

defaultproperties
{
    FireModeClass(0)=class'HxNet_SniperFire'
}
