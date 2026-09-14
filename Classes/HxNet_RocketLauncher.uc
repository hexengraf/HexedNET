class HxNet_RocketLauncher extends RocketLauncher
    DependsOn(HxNTWeapon)
    HideDropDown
    CacheExempt;

var private int StopFireTime[2];
var private bool bConfigCleared;
var private Pawn ClientSeekTarget;

replication
{
    reliable if (Role == ROLE_Authority && bNetOwner)
        ClientSeekTarget;

    reliable if (Role < Role_Authority)
        ServerStartFireBAS, ServerStopFireBAS;
}

simulated event PreBeginPlay()
{
    Super.PreBeginPlay();
    if (Level.NetMode != NM_DedicatedServer)
    {
        class'HxNTWeapon'.static.LoadDefaultConfig(
            Self, class'RocketLauncher', !default.bConfigCleared);
        default.bConfigCleared = true;
    }
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
    class'HxNTWeapon'.static.CheckStopFire(Self, StopFireTime[0], StopFireTime[1]);
}

simulated event ClientStopFire(int Mode)
{
    local HxNTWeapon.HxBAS BAS;

    if (Role < ROLE_Authority && WantsStopFireBAS(Mode))
    {
        BAS = class'HxNTWeapon'.static.EncodeBAS(Self, Mode);
        HxNet_RocketMultiFire(FireMode[Mode]).ApplyBAS(BAS);
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

    if (Pawn(Owner).Controller.IsInState('GameEnded')
        || Pawn(Owner).Controller.IsInState('RoundEnded'))
    {
        return;
    }
    if (Role < ROLE_Authority && WantsStartFireBAS(Mode))
    {
        if (StartFire(Mode))
        {
            BAS = class'HxNTWeapon'.static.EncodeBAS(Self, Mode);
            HxNet_RocketFire(FireMode[Mode]).ApplyBAS(BAS);
            ServerStartFireBAS(Mode, BAS);
            StopFireTime[Mode] = 3;
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
        HxNet_RocketMultiFire(FireMode[Mode]).ApplyBAS(BAS);
    }
    ServerStopFire(Mode);
}

function ServerStartFireBAS(byte Mode, HxNTWeapon.HxBAS BAS)
{
    HxNet_RocketFire(FireMode[Mode]).ApplyBAS(BAS);
    ServerStartFire(Mode);
}

simulated function bool StartFire(int Mode)
{
    local float ServerDelay;

    ServerDelay = Level.TimeSeconds - FireMode[Mode].NextFireTime;
    if (Super.StartFire(Mode))
    {
        if (FireMode[Mode].bServerDelayStartFire && HxNet_RocketFire(FireMode[Mode]) != None)
        {
            FireMode[Mode].NextFireTime -= ServerDelay + 0.001;
            HxNet_RocketFire(FireMode[Mode]).ServerDelay = ServerDelay;
        }
        return true;
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

simulated function bool WantsStopFireBAS(int Mode)
{
    // TODO: why applying on stop fire sometimes causes stale BAS to be consumed?
    // return HxNet_RocketMultiFire(FireMode[Mode]) != None
    //     && HxNet_RocketMultiFire(FireMode[Mode]).Load < 3
    //     && HxNet_RocketMultiFire(FireMode[Mode]).WantsPingCompensation();
    return false;
}

simulated function bool WantsStartFireBAS(int Mode)
{
    local int AltMode;

    AltMode = int(Mode == 0);
    return HxNet_RocketFire(FireMode[Mode]) != None
        && !FireMode[AltMode].bIsFiring
        && FireMode[AltMode].NextFireTime <= Level.TimeSeconds
        && HxNet_RocketFire(FireMode[Mode]).WantsPingCompensation();
}

defaultproperties
{
    FireModeClass(0)=class'HxNet_RocketFire'
    FireModeClass(1)=class'HxNet_RocketMultiFire'
}
