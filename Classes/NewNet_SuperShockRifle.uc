class NewNet_SuperShockRifle extends SuperShockRifle
    HideDropDown
    CacheExempt;

var private const class<Weapon> BaseClass;
var private bool bConfigCleared;

#include Classes\Include\WeaponBaseSuperShockRifle.uci

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
    BaseClass=class'SuperShockRifle'
    FireModeClass(0)=class'NewNet_SuperShockBeamFire'
    FireModeClass(1)=class'NewNet_SuperShockBeamFire'
}
