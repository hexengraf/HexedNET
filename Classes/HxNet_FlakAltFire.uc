class HxNet_FlakAltFire extends FlakAltFire
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
        ProjectileClass = class'HxNet_FlakShellPredicted';
        P = SpawnProjectile(Start, Dir);
        ProjectileClass = default.ProjectileClass;
        if (P != None)
        {
            HxNet_FlakShellPredicted(P).WeaponInfo = WeaponInfo;
        }
        return WeaponInfo.TrackProjectile(P, Index);
    }
    if (WantsPingCompensation())
    {
        ProjectileClass = class'HxNet_FlakShell';
        P = SpawnProjectile(Start, Dir);
        ProjectileClass = default.ProjectileClass;
        if (P != None)
        {
            HxNet_FlakShell(P).Client = Client;
            HexedNET.ForwardFallingProjectile(Weapon, P, Client.GetProjectileCompensationTime() + ServerDelay);
        }
        return P;
    }
    return SpawnProjectile(Start, Dir);
}

defaultproperties
{
    WeaponClass=class'FlakCannon'
}
