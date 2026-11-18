class HxNet_BioRifle extends BioRifle
    config(HexedCache)
    DependsOn(HxNTWeapon)
    HideDropDown
    CacheExempt;

var private HxNTClient Client;
var private int StopTime[2];

replication
{
    reliable if (Role < Role_Authority)
        ServerStartFireBAS, ServerStartFireSynced, ServerStopFireBAS;
}

simulated function bool WantsLagCompensation()
{
    return class'HxNTWeapon'.static.ValidateClient(Level, Instigator, Client)
        && Client.WantsLagCompensation();
}

simulated event WeaponTick(float DT)
{
    Super.WeaponTick(DT);
    class'HxNTWeapon'.static.CheckStopFire(Self, StopTime[0], StopTime[1]);
}

simulated event ClientStopFire(int Mode)
{
    local HxNTWeapon.HxBAS BAS;

    if (Role < ROLE_Authority && HxNet_BioChargedFire(FireMode[Mode]) != None
        && WantsLagCompensation())
    {
        HxNet_BioChargedFire(FireMode[Mode]).PrepareBAS(BAS,, true);
        StopFire(Mode);
        ServerStopFireBAS(Mode, BAS);
    }
    else
    {
        Super.ClientStopFire(Mode);
    }
    StopTime[Mode] = 0;
}

simulated event ClientStartFire(int Mode)
{
    local HxNTWeapon.HxBAS BAS;

    if (!Pawn(Owner).Controller.IsInState('GameEnded')
        && !Pawn(Owner).Controller.IsInState('RoundEnded')
        && StartFire(Mode) && Role < ROLE_Authority)
    {
        if (!WantsLagCompensation())
        {
            ServerStartFire(Mode);
        }
        else if (HxNet_BioFire(FireMode[Mode]) != None)
        {
            HxNet_BioFire(FireMode[Mode]).PrepareBAS(BAS, StopTime[Mode]);
            ServerStartFireBAS(Mode, BAS);
        }
        else
        {
            ServerStartFireSynced(Mode, HxNet_BioChargedFire(FireMode[Mode]).PrepareTimestamp());
        }
    }
}

function ServerStopFireBAS(byte Mode, HxNTWeapon.HxBAS BAS)
{
    if (FireMode[Mode].bIsFiring)
    {
        HxNet_BioChargedFire(FireMode[Mode]).ApplyBAS(BAS, true);
    }
    ServerStopFire(Mode);
}

function ServerStartFireBAS(byte Mode, HxNTWeapon.HxBAS BAS)
{
    HxNet_BioFire(FireMode[Mode]).ApplyBAS(BAS);
    ServerStartFire(Mode);
}

function ServerStartFireSynced(byte Mode, float Timestamp)
{
    HxNet_BioChargedFire(FireMode[Mode]).ApplyTimestamp(Timestamp);
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
        else if (HxNet_BioFire(FireMode[Mode]) != None)
        {
            HxNet_BioFire(FireMode[Mode]).SynchronizeFireTime(MaxDelay);
        }
        return FireMode[Mode].bIsFiring;
    }
    return false;
}

defaultproperties
{
    FireModeClass(0)=class'HxNet_BioFire'
    FireModeClass(1)=class'HxNet_BioChargedFire'
}
