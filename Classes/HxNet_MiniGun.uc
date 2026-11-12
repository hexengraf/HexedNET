class HxNet_MiniGun extends MiniGun
    config(HexedCache)
    DependsOn(HxNTWeapon)
    HideDropDown
    CacheExempt;

defaultproperties
{
    FireModeClass(0)=class'HxNet_MiniGunFire'
    FireModeClass(1)=class'HxNet_MiniGunAltFire'
}
