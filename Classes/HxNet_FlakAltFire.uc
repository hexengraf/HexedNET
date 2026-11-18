class HxNet_FlakAltFire extends FlakAltFire
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
        ProjectileClass = class'HxNet_FlakShellPredicted';
        P = SpawnProjectile(Start, Dir);
        if (P != None)
        {
            HxNet_FlakShellPredicted(P).WeaponInfo = WeaponInfo;
        }
        return WeaponInfo.AddPredictedProjectile(P);
    }
    ProjectileClass = class'HxNet_FlakShell';
    P = WeaponInfo.AssignUniqueID(SpawnProjectile(Start, Dir));
    ProjectileClass = default.ProjectileClass;
    if (P != None)
    {
        HxNet_FlakShell(P).Client = Client;
        HexedNET.ForwardFallingProjectile(Weapon, P, GetCompensationTime());
    }
    return P;
}

defaultproperties
{
    WeaponClass=class'FlakCannon'
}
