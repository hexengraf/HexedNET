class HxNet_LinkAltFire extends LinkAltFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTBaseProjectileFire.uci

function DoFireEffect()
{
    DoBaseFireEffect();
}

function Projectile SpawnHexedProjectile(Vector Start, Rotator Dir, optional int Index)
{
    local Projectile P;
    local float DeltaTime;

    if (Level.NetMode == NM_Client)
    {
        ProjectileClass = class'HxNet_LinkProjectileDummy';
        P = SpawnProjectile(Start, Dir);
        ProjectileClass = default.ProjectileClass;
        return Client.TrackDummy(P, class'LinkGun');
    }
    if (WantsPingCompensation())
    {
        ProjectileClass = class'HxNet_LinkProjectile';
        P = SpawnProjectile(Start, Dir);
        ProjectileClass = default.ProjectileClass;
        if (P != None)
        {
            HxNet_LinkProjectile(P).Client = Client;
            DeltaTime = Client.GetProjectilePing() + ServerDelay;
            HexedNET.ForwardLinearProjectile(Weapon, P, DeltaTime);
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
}
