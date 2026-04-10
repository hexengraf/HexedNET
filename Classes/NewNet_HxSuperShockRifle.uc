class NewNet_HxSuperShockRifle extends HxSuperShockRifle
    HideDropDown
    CacheExempt;

#include Classes\Include\WeaponBaseSuperShockRifle.uci

defaultproperties
{
    BaseClass=class'HxSuperShockRifle'
    FireModeClass(0)=class'NewNet_SuperShockBeamFire'
    FireModeClass(1)=class'NewNet_SuperShockBeamFire'
}
