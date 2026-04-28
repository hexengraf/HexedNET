class NewNet_LinkGun extends LinkGun
    HideDropDown
    CacheExempt;

const MAX_PROJECTILE_FUDGE = 0.075;

var int CurIndex;

var private MutHexedNET HexedNET;
var private HxNTClient Client;
var private HxNTClock NETClock;
var private const class<Weapon> BaseClass;
var private bool bConfigCleared;

replication
{
    reliable if (Role<ROLE_Authority)
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
    if (NewNet_LinkAltFire(FireMode[Mode]) != None)
    {
        NewNet_LinkAltFire(FireMode[Mode]).PingDT = FMin(Ping, MAX_PROJECTILE_FUDGE);
    }
    else if (NewNet_LinkFire(FireMode[Mode]) != None)
    {
        NewNet_LinkFire(FireMode[Mode]).PingDT = Ping;
    }
    ServerStartFire(Mode);
}

DefaultProperties
{
    BaseClass=class'LinkGun'
    FireModeClass(0)=class'NewNet_LinkAltFire'
    FireModeClass(1)=class'NewNet_LinkFire'
}
