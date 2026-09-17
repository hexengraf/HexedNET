class HxNet_ShockProjFire extends ShockProjFire
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
        ProjectileClass = class'HxNet_ShockProjectilePredicted';
        P = SpawnProjectile(Start, Dir);
        ProjectileClass = default.ProjectileClass;
        if (P != None)
        {
            HxNet_ShockProjectilePredicted(P).WeaponInfo = WeaponInfo;
        }
        return WeaponInfo.TrackProjectile(P, Index);
    }
    P = SpawnProjectile(Start, Dir);
    if (P != None && WantsPingCompensation())
    {
        HxNet_ShockProjectile(P).Client = Client;
        HexedNET.ForwardLinearProjectile(
            Weapon, P, Client.GetProjectileCompensationTime() + ServerDelay);
    }
    if (HexedNET != None)
    {
        HexedNET.RegisterShockProjectile(HxNet_ShockProjectile(P));
    }
    return P;
}

defaultproperties
{
    ProjectileClass=class'HxNet_ShockProjectile'
    WeaponClass=class'ShockRifle'
}
