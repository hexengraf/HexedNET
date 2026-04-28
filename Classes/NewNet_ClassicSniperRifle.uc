class NewNet_ClassicSniperRifle extends ClassicSniperRifle
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

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    if (Level.NetMode != NM_DedicatedServer)
    {
        ForceBaseClassConfig();
    }
}

simulated event NewNet_ClientStartFire(int Mode)
{
    if (Mode == 1)
    {
        Super.ClientStartFire(Mode);
    }
    else if (Role < ROLE_Authority)
    {
        if (StartFire(Mode))
        {
            NewNet_ServerStartFire(Mode, class'HxNTClient'.default.AveragePing);
        }
    }
    else
    {
        StartFire(Mode);
    }
}

function NewNet_ServerStartFire(byte Mode, float Ping)
{
    if (NewNet_ClassicSniperFire(FireMode[Mode]) != None)
    {
        NewNet_ClassicSniperFire(FireMode[Mode]).PingDT = Ping;
    }
    ServerStartFire(Mode);
}

DefaultProperties
{
    BaseClass=class'ClassicSniperRifle'
    FireModeClass(0)=class'NewNet_ClassicSniperFire'
}
