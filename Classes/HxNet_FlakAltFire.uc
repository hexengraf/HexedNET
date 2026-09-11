class HxNet_FlakAltFire extends FlakAltFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTBaseProjectileFire.uci

function DoFireEffect()
{
    DoBaseFireEffect();
}

function Projectile SpawnHexedProjectile(Vector Start, Rotator Dir, optional int Index)
{
    local Projectile P;

    if (Level.NetMode == NM_Client)
    {
        ProjectileClass = class'HxNet_FlakShellDummy';
        P = SpawnProjectile(Start, Dir);
        ProjectileClass = default.ProjectileClass;
        return Client.TrackDummy(P, class'FlakCannon');
    }
    if (WantsPingCompensation())
    {
        ProjectileClass = class'HxNet_FlakShell';
        P = SpawnProjectile(Start, Dir);
        ProjectileClass = default.ProjectileClass;
        if (P != None)
        {
            HxNet_FlakShell(P).Client = Client;
            HexedNET.ForwardFallingProjectile(Weapon, P, Client.GetProjectilePing() + ServerDelay);
        }
        return P;
    }
    return SpawnProjectile(Start, Dir);
}

defaultproperties
{
}
