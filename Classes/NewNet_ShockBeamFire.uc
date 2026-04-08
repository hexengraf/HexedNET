class NewNet_ShockBeamFire extends ShockBeamFire;

#include Classes\Include\WeaponFireShockBeam.uci

simulated function SpawnClientBeamEffect(Vector Start, Rotator Dir, Vector HitLocation, Vector HitNormal, int ReflectNum)
{
    NewNet_ShockRifle(Weapon).SpawnBeamEffect(HitLocation, HitNormal, start, dir, ReflectNum);
}

function ShockBeamEffect NewNet_SpawnBeamEffect(Vector Start, Rotator Dir)
{
    return  Weapon.Spawn(Class'NewNet_ShockBeamEffect', Weapon.Owner,, Start, Dir);
}

DefaultProperties
{
}
