class HxNet_BioFire extends BioFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTBaseProjectileFire.uci

function SaveDelayedState();

function DoFireEffect()
{
    DoBaseFireEffect();
}

function Projectile SpawnHexedProjectile(Vector Start, Rotator Dir)
{
    local Projectile P;

    if (Level.NetMode == NM_Client)
    {
        ProjectileClass = class'HxNet_BioGlobPredicted';
        P = SpawnProjectile(Start, Dir);
        if (P != None)
        {
            HxNet_BioGlobPredicted(P).WeaponInfo = WeaponInfo;
        }
        return WeaponInfo.AddPredictedProjectile(P);
    }
    ProjectileClass = class'HxNet_BioGlob';
    P = WeaponInfo.AssignUniqueID(SpawnProjectile(Start, Dir));
    ProjectileClass = default.ProjectileClass;
    if (P != None)
    {
        HxNet_BioGlob(P).Client = Client;
        HexedNET.ForwardFallingProjectile(Weapon, P, GetCompensationTime(), true);
    }
    return P;
}

defaultproperties
{
    WeaponClass=class'BioRifle'
}
