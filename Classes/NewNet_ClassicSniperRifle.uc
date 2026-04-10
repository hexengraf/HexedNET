class NewNet_ClassicSniperRifle extends ClassicSniperRifle
    HideDropDown
    CacheExempt;

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
            ValidateNETClockPointer();
            NewNet_ServerStartFire(Mode, NETClock.ClientCounter, NETClock.DT);
        }
    }
    else
    {
        StartFire(Mode);
    }
}

function NewNet_ServerStartFire(byte Mode, byte ClientCounter, float DT)
{
    ValidateNETClockPointer();
    if (NewNet_ClassicSniperFire(FireMode[Mode]) != None)
    {
        NewNet_ClassicSniperFire(FireMode[Mode]).PingDT = NETClock.GetPingDT(ClientCounter, DT);
        NewNet_ClassicSniperFire(FireMode[Mode]).bUseEnhancedNetCode = true;
    }
    ServerStartFire(Mode);
}

DefaultProperties
{
    BaseClass=class'ClassicSniperRifle'
    FireModeClass(0)=class'NewNet_ClassicSniperFire'
}
