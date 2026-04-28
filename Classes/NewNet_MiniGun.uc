class NewNet_MiniGun extends MiniGun
    HideDropDown
    CacheExempt;

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
    if (NewNet_MiniGunFire(FireMode[Mode]) != None)
    {
        NewNet_MiniGunFire(FireMode[Mode]).PingDT = Ping;
    }
    else if (NewNet_MiniGunAltFire(FireMode[Mode]) != None)
    {
        NewNet_MiniGunAltFire(FireMode[Mode]).PingDT = Ping;
    }
    ServerStartFire(Mode);
}

DefaultProperties
{
    BaseClass=class'MiniGun'
    FireModeClass(0)=class'NewNet_MiniGunFire'
    FireModeClass(1)=class'NewNet_MiniGunAltFire'
}
