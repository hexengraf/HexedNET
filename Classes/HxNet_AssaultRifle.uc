class HxNet_AssaultRifle extends AssaultRifle
    DependsOn(HxNTWeapon)
    HideDropDown
    CacheExempt;

var private MutHexedNET HexedNET;
var private HxNTClient Client;
var private int StopFireTime[2];
var private bool bConfigCleared;

replication
{
    reliable if (Role < Role_Authority)
        ServerStartFireBAS, ServerStopFireBAS;
}

simulated function PreBeginPlay()
{
    Super.PreBeginPlay();
    if (Level.NetMode != NM_DedicatedServer)
    {
        if (!default.bConfigCleared)
        {
            ClearConfig();
            default.bConfigCleared = true;
        }
        class'HxNTWeapon'.static.ForceBaseClassConfig(Self, class'AssaultRifle');
    }
}

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    if (Level.NetMode != NM_Client)
    {
        foreach DynamicActors(class'MutHexedNET', HexedNET) break;
    }
    else
    {
        class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client);
    }
}

simulated function bool WantsPingCompensation()
{
    return class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        && Client.WantsPingCompensation();
}

simulated event WeaponTick(float DT)
{
    Super.WeaponTick(DT);
    class'HxNTWeapon'.static.CheckStopFire(Self, StopFireTime[0], StopFireTime[1]);
}

simulated event ClientStopFire(int Mode)
{
    local HxNTWeapon.HxBAS BAS;

    if (Role == ROLE_Authority || HxNet_AssaultGrenade(FireMode[Mode]) == None
        || !WantsPingCompensation())
    {
        Super.ClientStopFire(Mode);
    }
    else
    {
        BAS = class'HxNTWeapon'.static.EncodeBAS(Self, Mode);
        HxNet_AssaultGrenade(FireMode[Mode]).ApplyBAS(BAS);
        StopFire(Mode);
        ServerStopFireBAS(Mode, BAS);
    }
    StopFireTime[Mode] = 0;
}

simulated event ClientStartFire(int Mode)
{
    local HxNTWeapon.HxBAS BAS;

    if (Role == ROLE_Authority || Pawn(Owner).Controller.IsInState('GameEnded')
        || Pawn(Owner).Controller.IsInState('RoundEnded')
        || HxNet_AssaultFire(FireMode[Mode]) == None || !WantsPingCompensation())
    {
        Super.ClientStartFire(Mode);
    }
    else if (StartFire(Mode))
    {
        BAS = class'HxNTWeapon'.static.EncodeBAS(Self, Mode);
        HxNet_AssaultFire(FireMode[Mode]).ApplyBAS(BAS);
        ServerStartFireBAS(Mode, BAS);
        StopFireTime[Mode] = 3;
    }
}

function ServerStopFireBAS(byte Mode, HxNTWeapon.HxBAS BAS)
{
    if (HxNet_AssaultGrenade(FireMode[Mode]) != None)
    {
        HxNet_AssaultGrenade(FireMode[Mode]).ApplyBAS(BAS);
    }
    ServerStopFire(Mode);
}

function ServerStartFireBAS(byte Mode, HxNTWeapon.HxBAS BAS)
{
    if (HxNet_AssaultFire(FireMode[Mode]) != None)
    {
        HxNet_AssaultFire(FireMode[Mode]).ApplyBAS(BAS);
    }
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
            if (HxNet_AssaultFire(FireMode[Mode]) != None)
            {
                FireMode[Mode].NextFireTime -= ServerDelay + 0.001;
                HxNet_AssaultFire(FireMode[Mode]).ServerDelay = ServerDelay;
            }
        }
        return true;
    }
    return false;
}

defaultproperties
{
    FireModeClass(0)=class'HxNet_AssaultFire'
    FireModeClass(1)=class'HxNet_AssaultGrenade'
}
