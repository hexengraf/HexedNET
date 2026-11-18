class HxNet_LinkAltFire extends LinkAltFire
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
        ProjectileClass = class'HxNet_LinkProjectilePredicted';
        P = SpawnProjectile(Start, Dir);
        if (P != None)
        {
            HxNet_LinkProjectilePredicted(P).WeaponInfo = WeaponInfo;
        }
        return WeaponInfo.AddPredictedProjectile(P);
    }
    ProjectileClass = class'HxNet_LinkProjectile';
    P = WeaponInfo.AssignUniqueID(SpawnProjectile(Start, Dir));
    ProjectileClass = default.ProjectileClass;
    if (P != None)
    {
        HxNet_LinkProjectile(P).Client = Client;
        HexedNET.ForwardLinearProjectile(Weapon, P, GetCompensationTime());
    }
    return P;
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
