class HxNet_ClassicSniperRifle extends ClassicSniperRifle
    config(HexedCache)
    DependsOn(HxNTWeapon)
    HideDropDown
    CacheExempt;

var private int StopFireTime[2];

replication
{
    reliable if (Role < Role_Authority)
        ServerStartFireBAS, ServerStartFireBASRecon;
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
    local Actor ClientHit;

    if (Pawn(Owner).Controller.IsInState('GameEnded')
        || Pawn(Owner).Controller.IsInState('RoundEnded'))
    {
        return;
    }
    if (Role < ROLE_Authority && WantsStartFireBAS(Mode))
    {
        if (StartFire(Mode))
        {
            if (HxNet_ClassicSniperFire(FireMode[Mode]).PrepareBAS(
                BAS, StopFireTime[Mode], ClientHit))
            {
                ServerStartFireBASRecon(Mode, BAS, ClientHit);
            }
            else
            {
                ServerStartFireBAS(Mode, BAS);
            }
        }
    }
    else
    {
        Super.ClientStartFire(Mode);
    }
}

function ServerStartFireBAS(byte Mode, HxNTWeapon.HxBAS BAS)
{
    HxNet_ClassicSniperFire(FireMode[Mode]).ApplyBAS(BAS);
    ServerStartFire(Mode);
}

function ServerStartFireBASRecon(byte Mode, HxNTWeapon.HxBAS BAS, Actor ClientHit)
{
    HxNet_ClassicSniperFire(FireMode[Mode]).ApplyBAS(BAS, ClientHit, true);
    ServerStartFire(Mode);
}

simulated function bool StartFire(int Mode)
{
    local float MaxDelay;

    MaxDelay = Level.TimeSeconds - FireMode[Mode].NextFireTime;
    if (Super.StartFire(Mode))
    {
        if (Role < ROLE_Authority)
        {
            FireMode[Mode].bIsFiring =
                FireMode[Mode].NextFireTime <= Level.TimeSeconds + FireMode[Mode].PreFireTime;
        }
        else if (HxNet_ClassicSniperFire(FireMode[Mode]) != None)
        {
            HxNet_ClassicSniperFire(FireMode[Mode]).SynchronizeFireTime(MaxDelay);
        }
        return FireMode[Mode].bIsFiring;
    }
    return false;
}

simulated function bool WantsStartFireBAS(int Mode)
{
    return HxNet_ClassicSniperFire(FireMode[Mode]) != None
        && HxNet_ClassicSniperFire(FireMode[Mode]).WantsLagCompensation();
}

defaultproperties
{
    FireModeClass(0) = class'HxNet_ClassicSniperFire'
}
