class NewNet_HxZoomSuperShockRifle extends HxZoomSuperShockRifle
    HideDropDown
    CacheExempt;

#include Classes\Include\WeaponBaseZoomSuperShockRifle.uci

DefaultProperties
{
    BaseClass=class'ZoomSuperShockRifle'
    FireModeClass(0)=class'NewNet_ZoomSuperShockBeamFire'
}
