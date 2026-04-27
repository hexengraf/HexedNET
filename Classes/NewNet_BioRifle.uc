class NewNet_BioRifle extends BioRifle
    HideDropDown
    CacheExempt;

const MAX_PROJECTILE_FUDGE = 0.075;

var int CurIndex;

var private HxNTClock NETClock;
var private const class<Weapon> BaseClass;
var private bool bConfigCleared;

replication
{
    reliable if (Role < ROLE_Authority)
        NewNet_ServerStartFire;

    unreliable if (Role == Role_Authority && bNetOwner)
        CurIndex;
}

#include Classes\Include\WeaponBaseFunctions.uci
#include Classes\Include\WeaponStartFireStandard.uci

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    if (Level.NetMode != NM_DedicatedServer)
    {
        ForceBaseClassConfig();
    }
}

function NewNet_ServerStartFire(byte Mode, float Ping)
{
    ValidateNETClockPointer();
    if (NewNet_BioFire(FireMode[Mode]) != None)
    {
        NewNet_BioFire(FireMode[Mode]).PingDT = FMin(Ping, MAX_PROJECTILE_FUDGE);
        NewNet_BioFire(FireMode[Mode]).bUseEnhancedNetCode = true;
    }
    else if (NewNet_BioChargedFire(FireMode[Mode]) != None)
    {
        NewNet_BioChargedFire(FireMode[Mode]).PingDT = FMin(Ping, MAX_PROJECTILE_FUDGE);
        NewNet_BioChargedFire(FireMode[Mode]).bUseEnhancedNetCode = true;
    }
    ServerStartFire(Mode);
}

DefaultProperties
{
    BaseClass=class'BioRifle'
    FireModeClass(0)=class'NewNet_BioFire'
    FireModeClass(1)=class'NewNet_BioChargedFire'
}
