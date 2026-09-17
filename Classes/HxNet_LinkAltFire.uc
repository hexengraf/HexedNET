class HxNet_LinkAltFire extends LinkAltFire
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
        ProjectileClass = class'HxNet_LinkProjectilePredicted';
        P = SpawnProjectile(Start, Dir);
        ProjectileClass = default.ProjectileClass;
        if (P != None)
        {
            HxNet_LinkProjectilePredicted(P).WeaponInfo = WeaponInfo;
        }
        return WeaponInfo.TrackProjectile(P, Index);
    }
    if (WantsPingCompensation())
    {
        ProjectileClass = class'HxNet_LinkProjectile';
        P = SpawnProjectile(Start, Dir);
        ProjectileClass = default.ProjectileClass;
        if (P != None)
        {
            HxNet_LinkProjectile(P).Client = Client;
            HexedNET.ForwardLinearProjectile(
                Weapon, P, Client.GetProjectileCompensationTime() + ServerDelay);
        }
        return P;
    }
    return SpawnProjectile(Start, Dir);
}

function Projectile SpawnProjectile(Vector Start, Rotator Dir)
{
    local LinkProjectile Proj;

    Start += Vector(Dir) * 10.0 * LinkGun(Weapon).Links;
    Proj = LinkProjectile(Weapon.Spawn(ProjectileClass,,, Start, Dir));
    if (Proj != None)
    {
        Proj.Links = LinkGun(Weapon).Links;
        Proj.LinkAdjust();
    }
    return Proj;
}

defaultproperties
{
    WeaponClass=class'LinkGun'
}
