class NewNet_BioRifle extends BioRifle
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
    BaseClass=class'BioRifle'
    FireModeClass(0)=class'NewNet_BioFire'
    FireModeClass(1)=class'NewNet_BioChargedFire'
}
