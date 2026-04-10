class NewNet_ZoomSuperShockRifle extends ZoomSuperShockRifle
    HideDropDown
    CacheExempt;

var private const class<Weapon> BaseClass;
var private bool bConfigCleared;

#include Classes\Include\WeaponBaseZoomSuperShockRifle.uci

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
    BaseClass=class'ZoomSuperShockRifle'
    FireModeClass(0)=class'NewNet_ZoomSuperShockBeamFire'
}
