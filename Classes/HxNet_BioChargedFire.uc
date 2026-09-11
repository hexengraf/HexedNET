class HxNet_BioChargedFire extends BioChargedFire
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
        ProjectileClass = class'HxNet_BioGlobDummy';
        P = SpawnProjectile(Start, Dir);
        ProjectileClass = default.ProjectileClass;
        return Client.TrackDummy(P, class'BioRifle');
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
                Weapon, P, Client.GetProjectilePing() + ServerDelay, true);
        }
        return P;
    }
    return SpawnProjectile(Start, Dir);
}

function Projectile SpawnProjectile(Vector Start, Rotator Dir)
{
    local BioGlob Glob;

    if (Level.NetMode != NM_Client)
    {
        GotoState('');
    }
    if (GoopLoad != 0)
    {
        Glob = BioGlob(Weapon.Spawn(ProjectileClass,,, Start, Dir));
        if (Glob != None)
        {
            Glob.Damage *= DamageAtten;
            Glob.SetGoopLevel(GoopLoad);
            Glob.AdjustSpeed();
        }
        if (Level.NetMode != NM_Client)
        {
            GoopLoad = 0;
            if (Weapon.AmmoAmount(ThisModeNum) <= 0)
            {
                Weapon.OutOfAmmo();
            }
        }
    }
    return Glob;
}

defaultproperties
{
}
