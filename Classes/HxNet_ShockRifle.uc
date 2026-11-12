class HxNet_ShockRifle extends ShockRifle
    config(HexedCache)
    DependsOn(HxNTWeapon)
    HideDropDown
    CacheExempt;

var private int StopFireTime[2];

replication
{
    reliable if (Role < ROLE_Authority)
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
            if (HxNet_ShockBeamFire(FireMode[Mode]) != None)
            {
                if (HxNet_ShockBeamFire(FireMode[Mode]).PrepareBAS(
                    BAS, StopFireTime[Mode], ClientHit))
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
                HxNet_ShockProjFire(FireMode[Mode]).PrepareBAS(BAS, StopFireTime[Mode]);
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
    if (HxNet_ShockBeamFire(FireMode[Mode]) != None)
    {
        HxNet_ShockBeamFire(FireMode[Mode]).ApplyBAS(BAS);
    }
    else
    {
        HxNet_ShockProjFire(FireMode[Mode]).ApplyBAS(BAS);
    }
    ServerStartFire(Mode);
}

function ServerStartFireBASRecon(byte Mode, HxNTWeapon.HxBAS BAS, Actor ClientHit)
{
    HxNet_ShockBeamFire(FireMode[Mode]).ApplyBAS(BAS, ClientHit, true);
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
            else
            {
                HxNet_ShockProjFire(FireMode[Mode]).ServerDelay = ServerDelay;
            }
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
    if (HxNet_ShockBeamFire(FireMode[Mode]) != None)
    {
        return HxNet_ShockBeamFire(FireMode[Mode]).WantsLagCompensation();
    }
    return HxNet_ShockProjFire(FireMode[Mode]).WantsLagCompensation();
}

defaultproperties
{
    FireModeClass(0)=class'HxNet_ShockBeamFire'
    FireModeClass(1)=class'HxNet_ShockProjFire'
}
