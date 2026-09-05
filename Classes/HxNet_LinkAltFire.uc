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
        return Client.TrackDummyProjectile(P, class'LinkGun');
    }
    if (WantsPingCompensation())
    {
        ProjectileClass = class'HxNet_LinkProjectile';
        P = SpawnProjectile(Start, Dir);
        ProjectileClass = default.ProjectileClass;
        DeltaTime = Client.GetProjectilePing() + ServerDelay;
        HexedNET.ExtrapolateLinearProjectile(Weapon, P, DeltaTime);
        return P;
    }
    return SpawnProjectile(Start, Dir);
}

defaultproperties
{
}
