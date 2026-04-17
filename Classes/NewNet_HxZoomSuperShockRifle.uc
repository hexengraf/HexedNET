class NewNet_HxZoomSuperShockRifle extends HxZoomSuperShockRifle
    HideDropDown
    CacheExempt;

#include Classes\Include\WeaponBaseZoomSuperShockRifle.uci

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    if (Level.NetMode != NM_DedicatedServer)
    {
        RefreshConfiguration();
    }
}

DefaultProperties
{
    FireModeClass(0)=class'NewNet_ZoomSuperShockBeamFire'
}
