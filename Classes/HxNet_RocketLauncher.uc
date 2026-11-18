class HxNet_RocketLauncher extends RocketLauncher
    config(HexedCache)
    DependsOn(HxNTWeapon)
    HideDropDown
    CacheExempt;

var private HxNTClient Client;
var private int StopTime[2];
var private Pawn ClientSeekTarget;

replication
{
    reliable if (Role == ROLE_Authority && bNetOwner)
        ClientSeekTarget;

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
    if (Role == ROLE_Authority)
    {
        ClientSeekTarget = SeekTarget;
    }
    else
    {
        SeekTarget = ClientSeekTarget;
    }
    class'HxNTWeapon'.static.CheckStopFire(Self, StopTime[0], StopTime[1]);
}

simulated event ClientStopFire(int Mode)
{
    local HxNTWeapon.HxBAS BAS;

    if (Role < ROLE_Authority && HxNet_RocketMultiFire(FireMode[Mode]) != None
        && HxNet_RocketMultiFire(FireMode[Mode]).Load < 3
        && WantsLagCompensation() && ReadyToFire(Mode))
    {
        HxNet_RocketMultiFire(FireMode[Mode]).PrepareBAS(BAS,, true);
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
    local int OtherMode;

	if (RocketMultiFire(FireMode[Mode]) != None)
	{
		SetTightSpread(false);
	}
    else
    {
        OtherMode = int(Mode == 0);
		if (FireMode[OtherMode].bIsFiring || (FireMode[OtherMode].NextFireTime > Level.TimeSeconds))
		{
			if (FireMode[OtherMode].Load > 0)
            {
				SetTightSpread(true);
            }
			return;
		}
	}
    if (!Pawn(Owner).Controller.IsInState('GameEnded')
        && !Pawn(Owner).Controller.IsInState('RoundEnded')
        && StartFire(Mode) && Role < ROLE_Authority)
    {
        if (!WantsLagCompensation())
        {
            ServerStartFire(Mode);
        }
        else if (HxNet_RocketFire(FireMode[Mode]) != None)
        {
            HxNet_RocketFire(FireMode[Mode]).PrepareBAS(BAS, StopTime[Mode]);
            ServerStartFireBAS(Mode, BAS);
        }
        else
        {
            ServerStartFireSynced(Mode, HxNet_RocketMultiFire(FireMode[Mode]).PrepareTimestamp());
        }
    }
}

function ServerStopFireBAS(byte Mode, HxNTWeapon.HxBAS BAS)
{
    if (FireMode[Mode].bIsFiring)
    {
        HxNet_RocketMultiFire(FireMode[Mode]).ApplyBAS(BAS, true);
    }
    ServerStopFire(Mode);
}

function ServerStartFireBAS(byte Mode, HxNTWeapon.HxBAS BAS)
{
    HxNet_RocketFire(FireMode[Mode]).ApplyBAS(BAS);
    ServerStartFire(Mode);
}

function ServerStartFireSynced(byte Mode, float Timestamp)
{
    HxNet_RocketMultiFire(FireMode[Mode]).ApplyTimestamp(Timestamp);
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
        else if (HxNet_RocketFire(FireMode[Mode]) != None)
        {
            HxNet_RocketFire(FireMode[Mode]).SynchronizeFireTime(MaxDelay);
        }
        return FireMode[Mode].bIsFiring;
    }
    return false;
}

static function RocketProj StaticSpawnProjectile(RocketLauncher Weapon,
                                                 Vector Start,
                                                 Rotator Dir,
                                                 class<RocketProj> RocketClass,
                                                 class<SeekingRocketProj> SeekingRocketClass)
{
    local SeekingRocketProj SeekingRocket;

    if (Weapon.bLockedOn && Weapon.SeekTarget != None)
    {
        SeekingRocket = Weapon.Spawn(SeekingRocketClass,,, Start, Dir);
        SeekingRocket.Seeking = Weapon.SeekTarget;
        return SeekingRocket;
    }
    return Weapon.Spawn(RocketClass,,, Start, Dir);
}

defaultproperties
{
    FireModeClass(0)=class'HxNet_RocketFire'
    FireModeClass(1)=class'HxNet_RocketMultiFire'
}
