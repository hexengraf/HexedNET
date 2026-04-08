class NewNet_SuperShockBeamFire extends SuperShockBeamFire;

#include Classes\Include\WeaponFireShockBeam.uci

simulated function SpawnClientBeamEffect(Vector Start, Rotator Dir, Vector HitLocation, Vector HitNormal, int ReflectNum)
{
    NewNet_SuperShockRifle(Weapon).SpawnBeamEffect(HitLocation, HitNormal, start, dir, ReflectNum);
}

function ShockBeamEffect NewNet_SpawnBeamEffect(Vector Start, Rotator Dir)
{
    if (Instigator.PlayerReplicationInfo.Team != None
        && Instigator.PlayerReplicationInfo.Team.TeamIndex == 1)
    {
        return Weapon.Spawn(class'NewNet_BlueSuperShockBeam', Weapon.Owner,, Start, Dir);
    }
    return Weapon.Spawn(class'NewNet_SuperShockBeamEffect', Weapon.Owner,, Start, Dir);
}

DefaultProperties
{
}
