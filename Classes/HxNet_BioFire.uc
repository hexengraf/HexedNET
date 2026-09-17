class HxNet_BioFire extends BioFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTBaseProjectileFire.uci

function DoFireEffect()
{
    DoBaseFireEffect();
}

function Projectile SpawnHexedProjectile(HxNTWeaponInfo WeaponInfo,
                                         Vector Start,
                                         Rotator Dir,
                                         optional int Index)
{
    local Projectile P;

    if (Level.NetMode == NM_Client)
    {
        ProjectileClass = class'HxNet_BioGlobPredicted';
        P = SpawnProjectile(Start, Dir);
        ProjectileClass = default.ProjectileClass;
        if (P != None)
        {
            HxNet_BioGlobPredicted(P).WeaponInfo = WeaponInfo;
        }
        return WeaponInfo.TrackProjectile(P, Index);
    }
    if (WantsPingCompensation())
    {
        ProjectileClass = class'HxNet_BioGlob';
        P = SpawnProjectile(Start, Dir);
        ProjectileClass = default.ProjectileClass;
        if (P != None)
        {
            HxNet_BioGlob(P).Client = Client;
            HexedNET.ForwardFallingProjectile(
                Weapon, P, Client.GetProjectileCompensationTime() + ServerDelay, true);
        }
        return P;
    }
    return SpawnProjectile(Start, Dir);
}

defaultproperties
{
    WeaponClass=class'BioRifle'
}
