class HxNet_SniperRifle extends SniperRifle
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
            BAS = class'HxNTWeapon'.static.EncodeBAS(Self, Mode, true);
            StopFireTime[Mode] = HxNet_SniperFire(FireMode[Mode]).ApplyBAS(BAS, ClientHit);
            if (ClientHit == None)
            {
                ServerStartFireBAS(Mode, BAS);
            }
            else
            {
                ServerStartFireBASRecon(Mode, BAS, ClientHit);
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
    HxNet_SniperFire(FireMode[Mode]).ApplyBAS(BAS);
    ServerStartFire(Mode);
}

function ServerStartFireBASRecon(byte Mode, HxNTWeapon.HxBAS BAS, Actor ClientHit)
{
    HxNet_SniperFire(FireMode[Mode]).ApplyBAS(BAS, ClientHit);
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
        if (Role < ROLE_Authority)
        {
            FireMode[Mode].bIsFiring =
                FireMode[Mode].NextFireTime <= Level.TimeSeconds + FireMode[Mode].PreFireTime;
        }
        return FireMode[Mode].bIsFiring;
    }
    return false;
}

simulated function bool WantsStartFireBAS(int Mode)
{
    return HxNet_SniperFire(FireMode[Mode]) != None
        && HxNet_SniperFire(FireMode[Mode]).WantsLagCompensation();
}

defaultproperties
{
    FireModeClass(0)=class'HxNet_SniperFire'
}
