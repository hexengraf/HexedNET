class NewNet_SuperShockBeamFire extends SuperShockBeamFire;

#include Classes\Include\WeaponFireSuperShockBeam.uci

function PreBeginPlay()
{
    Super.PreBeginPlay();
    foreach Weapon.DynamicActors(class'MutHexedNET', HexedNET) break;
}
