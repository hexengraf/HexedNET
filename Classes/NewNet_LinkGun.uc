class NewNet_LinkGun extends LinkGun
    HideDropDown
    CacheExempt;

var int CurIndex;

var private const class<Weapon> BaseClass;
var private bool bConfigCleared;

replication
{
    unreliable if (Role == Role_Authority && bNetOwner)
        CurIndex;
}

#include Classes\Include\ForceBaseClassConfig.uci

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    if (Level.NetMode != NM_DedicatedServer)
    {
        ForceBaseClassConfig();
    }
}

DefaultProperties
{
    BaseClass=class'LinkGun'
    FireModeClass(0)=class'NewNet_LinkAltFire'
    FireModeClass(1)=class'NewNet_LinkFire'
}
