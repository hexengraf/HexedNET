class HxNet_HxSuperShockRifle extends HxSuperShockRifle
    config(HexedCache)
    DependsOn(HxNTWeapon)
    HideDropDown
    CacheExempt;

var private HxNTClient Client;
var private int StopTime[2];

replication
{
    reliable if (Role < ROLE_Authority)
        ServerStartFireBAS, ServerStartFireBASRecon;
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
    local Actor ClientHit;

    if (!Pawn(Owner).Controller.IsInState('GameEnded')
        && !Pawn(Owner).Controller.IsInState('RoundEnded')
        && StartFire(Mode) && Role < ROLE_Authority)
    {
        if (HxNet_SuperShockBeamFire(FireMode[Mode]) != None && WantsLagCompensation())
        {
            if (HxNet_SuperShockBeamFire(FireMode[Mode]).PrepareBAS(BAS, StopTime[Mode], ClientHit))
            {
                ServerStartFireBASRecon(Mode, BAS, ClientHit);
            }
            else
            {
                ServerStartFireBAS(Mode, BAS);
            }
        }
        else
        {
            ServerStartFire(Mode);
        }
    }
}

function ServerStartFireBAS(byte Mode, HxNTWeapon.HxBAS BAS)
{
    HxNet_SuperShockBeamFire(FireMode[Mode]).ApplyBAS(BAS);
    ServerStartFire(Mode);
}

function ServerStartFireBASRecon(byte Mode, HxNTWeapon.HxBAS BAS, Actor HitClient)
{
    HxNet_SuperShockBeamFire(FireMode[Mode]).ApplyBAS(BAS, HitClient, true);
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
        else if (HxNet_SuperShockBeamFire(FireMode[Mode]) != None)
        {
            HxNet_SuperShockBeamFire(FireMode[Mode]).SynchronizeFireTime(MaxDelay);
        }
        return FireMode[Mode].bIsFiring;
    }
    return false;
}

defaultproperties
{
    FireModeClass(0)=class'HxNet_SuperShockBeamFire'
    FireModeClass(1)=class'HxNet_SuperShockBeamFire'
}
