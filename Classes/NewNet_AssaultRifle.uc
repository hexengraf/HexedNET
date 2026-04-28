class NewNet_AssaultRifle extends AssaultRifle
    HideDropDown
    CacheExempt;

const MAX_PROJECTILE_FUDGE = 0.075;

var private MutHexedNET HexedNET;
var private HxNTClient Client;
var private HxNTClock NETClock;
var private const class<Weapon> BaseClass;
var private bool bConfigCleared;

replication
{
    reliable if (Role < ROLE_Authority)
        NewNet_ServerStartFire;
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
    if (NewNet_AssaultFire(FireMode[Mode]) != None)
    {
        NewNet_AssaultFire(FireMode[Mode]).PingDT = Ping;
    }
    else if (NewNet_AssaultGrenade(FireMode[Mode]) != None)
    {
        NewNet_AssaultGrenade(FireMode[Mode]).PingDT = FMin(Ping, MAX_PROJECTILE_FUDGE);
    }
    ServerStartFire(Mode);
}

DefaultProperties
{
    BaseClass=class'AssaultRifle'
    FireModeClass(0)=class'NewNet_AssaultFire'
    FireModeClass(1)=class'NewNet_AssaultGrenade'
}
