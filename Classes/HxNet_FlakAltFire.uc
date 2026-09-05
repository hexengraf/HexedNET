class HxNet_FlakAltFire extends FlakAltFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTFallingProjectileFire.uci

defaultproperties
{
    WeaponClass=class'FlakCannon'
    DummyProjectileClass=class'HxNet_FlakShellDummy'
    ExtrapolatedProjectileClass=class'HxNet_FlakShell'
}
