class HxNet_BioChargedFire extends BioChargedFire
    DependsOn(HxNTWeapon);

var private int DelayedGoopLoad;
#include Classes\Include\HxNTBaseProjectileFire.uci

function SaveDelayedState()
{
    DelayedGoopLoad = GoopLoad;
}

function FlashMuzzleFlash()
{
    Super.FlashMuzzleFlash();
    // TODO: Temporary fix, OU will fix it eventually.
    GotoState('');
}

function DoFireEffect()
{
    local int SavedGoopLoad;

    if (bIsDelayed)
    {
        SavedGoopLoad = GoopLoad;
        GoopLoad = DelayedGoopLoad;
        DoBaseFireEffect();
        GoopLoad = SavedGoopLoad;
    }
    else
    {
        DoBaseFireEffect();
    }
}

function Projectile SpawnHexedProjectile(HxNTWeaponInfo WeaponInfo,
                                         Vector Start,
                                         Rotator Dir,
                                         optional int Index)
{
    local Projectile P;

    if (Level.NetMode == NM_Client)
    {
        ProjectileClass = class'HxNet_BioGlobPredicted';
        P = SpawnProjectile(Start, Dir);
        ProjectileClass = default.ProjectileClass;
        if (P != None)
        {
            HxNet_BioGlobPredicted(P).WeaponInfo = WeaponInfo;
        }
        return WeaponInfo.TrackProjectile(P, Index);
    }
    if (WantsLagCompensation())
    {
        ProjectileClass = class'HxNet_BioGlob';
        P = SpawnProjectile(Start, Dir);
        ProjectileClass = default.ProjectileClass;
        if (P != None)
        {
            HxNet_BioGlob(P).Client = Client;
            HexedNET.ForwardFallingProjectile(
                Weapon, P, Client.GetProjectileCompensationTime() + ServerDelay, true);
        }
        return P;
    }
    return SpawnProjectile(Start, Dir);
}

function Projectile SpawnProjectile(Vector Start, Rotator Dir)
{
    local BioGlob Glob;

    if (GoopLoad != 0)
    {
        Glob = BioGlob(Weapon.Spawn(ProjectileClass,,, Start, Dir));
        if (Glob != None)
        {
            Glob.Damage *= DamageAtten;
            Glob.SetGoopLevel(GoopLoad);
            Glob.AdjustSpeed();
        }
        GoopLoad = 0;
        if (Weapon.Role == ROLE_Authority)
        {
            GotoState('');
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
    WeaponClass=class'BioRifle'
}
