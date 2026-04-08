class NewNet_SuperShockBeamFire extends SuperShockBeamFire;

#include Classes\Include\WeaponFireShockBeam.uci

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
