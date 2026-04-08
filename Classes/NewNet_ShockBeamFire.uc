class NewNet_ShockBeamFire extends ShockBeamFire;

#include Classes\Include\WeaponFireShockBeam.uci

function ShockBeamEffect NewNet_SpawnBeamEffect(Vector Start, Rotator Dir)
{
    return  Weapon.Spawn(Class'NewNet_ShockBeamEffect', Weapon.Owner,, Start, Dir);
}

DefaultProperties
{
}
