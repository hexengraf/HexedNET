class HxNet_AssaultRifle extends AssaultRifle
    config(HexedCache)
    DependsOn(HxNTWeapon)
    HideDropDown
    CacheExempt;

var private int StopFireTime[2];

replication
{
    reliable if (Role < Role_Authority)
        ServerStartFireBAS, ServerStartFireBASRecon, ServerStopFireBAS;
}

simulated event WeaponTick(float DT)
{
    Super.WeaponTick(DT);
    class'HxNTWeapon'.static.CheckStopFire(Self, StopFireTime[0], StopFireTime[1]);
}

simulated event ClientStopFire(int Mode)
{
    local HxNTWeapon.HxBAS BAS;

    if (Role < ROLE_Authority && WantsStopFireBAS(Mode))
    {
        HxNet_AssaultGrenade(FireMode[Mode]).PrepareBAS(BAS);
        StopFire(Mode);
        ServerStopFireBAS(Mode, BAS);
    }
    else
    {
        Super.ClientStopFire(Mode);
    }
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
            if (HxNet_AssaultFire(FireMode[Mode]).PrepareBAS(BAS, StopFireTime[Mode], ClientHit))
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

function ServerStopFireBAS(byte Mode, HxNTWeapon.HxBAS BAS)
{
    if (FireMode[Mode].bIsFiring)
    {
        HxNet_AssaultGrenade(FireMode[Mode]).ApplyBAS(BAS);
    }
    ServerStopFire(Mode);
}

function ServerStartFireBAS(byte Mode, HxNTWeapon.HxBAS BAS)
{
    HxNet_AssaultFire(FireMode[Mode]).ApplyBAS(BAS);
    ServerStartFire(Mode);
}

function ServerStartFireBASRecon(byte Mode, HxNTWeapon.HxBAS BAS, Actor ClientHit)
{
    HxNet_AssaultFire(FireMode[Mode]).ApplyBAS(BAS, ClientHit, true);
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
        else if (HxNet_AssaultFire(FireMode[Mode]) != None)
        {
            HxNet_AssaultFire(FireMode[Mode]).SynchronizeFireTime(MaxDelay);
        }
        return FireMode[Mode].bIsFiring;
    }
    return false;
}

simulated function bool WantsStopFireBAS(int Mode)
{
    return HxNet_AssaultGrenade(FireMode[Mode]) != None
        && HxNet_AssaultGrenade(FireMode[Mode]).WantsLagCompensation();
}

simulated function bool WantsStartFireBAS(int Mode)
{
    return HxNet_AssaultFire(FireMode[Mode]) != None
        && HxNet_AssaultFire(FireMode[Mode]).WantsLagCompensation();
}

defaultproperties
{
    FireModeClass(0)=class'HxNet_AssaultFire'
    FireModeClass(1)=class'HxNet_AssaultGrenade'
}
