class HxNet_BioFire extends BioFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTFallingProjectileFire.uci

defaultproperties
{
    WeaponClass=class'BioRifle'
    DummyProjectileClass=class'HxNet_BioGlobDummy'
    HexedProjectileClass=class'HxNet_BioGlob'
}
