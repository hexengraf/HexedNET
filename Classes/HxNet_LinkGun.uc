class HxNet_LinkGun extends LinkGun
    config(HexedCache)
    DependsOn(HxNTWeapon)
    HideDropDown
    CacheExempt;

var private HxNTClient Client;
var private int StopTime[2];

replication
{
    reliable if (Role < Role_Authority)
        ServerStartFireBAS;
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
    Super.ClientStopFire(Mode);
    StopTime[Mode] = 0;
}

simulated event ClientStartFire(int Mode)
{
    local HxNTWeapon.HxBAS BAS;

    if (!Pawn(Owner).Controller.IsInState('GameEnded')
        && !Pawn(Owner).Controller.IsInState('RoundEnded')
        && StartFire(Mode) && Role < ROLE_Authority)
    {
        if (HxNet_LinkAltFire(FireMode[Mode]) != None && WantsLagCompensation())
        {
            HxNet_LinkAltFire(FireMode[Mode]).PrepareBAS(BAS, StopTime[Mode]);
            ServerStartFireBAS(Mode, BAS);
        }
        else
        {
            ServerStartFire(Mode);
        }
    }
}

function ServerStartFireBAS(byte Mode, HxNTWeapon.HxBAS BAS)
{
    HxNet_LinkAltFire(FireMode[Mode]).ApplyBAS(BAS);
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
        else if (HxNet_LinkAltFire(FireMode[Mode]) != None)
        {
            HxNet_LinkAltFire(FireMode[Mode]).SynchronizeFireTime(MaxDelay);
        }
        return FireMode[Mode].bIsFiring;
    }
    return false;
}

defaultproperties
{
    FireModeClass(0)=class'HxNet_LinkAltFire'
    FireModeClass(1)=class'HxNet_LinkFire'
}
