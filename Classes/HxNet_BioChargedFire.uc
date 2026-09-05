class HxNet_BioChargedFire extends BioChargedFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTFallingProjectileFire.uci

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

DefaultProperties
{
    WeaponClass=class'BioRifle'
    DummyProjectileClass=class'HxNet_BioGlobDummy'
    ExtrapolatedProjectileClass=class'HxNet_BioGlob'
}
