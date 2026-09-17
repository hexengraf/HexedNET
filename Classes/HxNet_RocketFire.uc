class HxNet_RocketFire extends RocketFire
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
        P = SpawnIndexedProjectile(
            Start, Dir, class'HxNet_RocketProjPredicted', class'HxNet_SeekingRocketProjPredicted');
        if (HxNet_RocketProjPredicted(P) != None)
        {
            HxNet_RocketProjPredicted(P).WeaponInfo = WeaponInfo;
        }
        else if (HxNet_SeekingRocketProjPredicted(P) != None)
        {
            HxNet_SeekingRocketProjPredicted(P).WeaponInfo = WeaponInfo;
        }
        return WeaponInfo.TrackProjectile(P, Index);
    }
    if (WantsPingCompensation())
    {
        P = SpawnIndexedProjectile(
            Start, Dir, class'HxNet_RocketProj', class'HxNet_SeekingRocketProj');
        if (P != None)
        {
            if (HxNet_RocketProj(P) != None)
            {
                HxNet_RocketProj(P).Client = Client;
                HxNet_RocketProj(P).Index = Index;
            }
            else
            {
                HxNet_SeekingRocketProj(P).Client = Client;
                HxNet_SeekingRocketProj(P).Index = Index;
            }
            HexedNET.ForwardLinearProjectile(Weapon, P, Client.GetProjectileCompensationTime() + ServerDelay);
        }
        return P;
    }
    return SpawnProjectile(Start, Dir);
}

function RocketProj SpawnIndexedProjectile(Vector Start,
                                           Rotator Dir,
                                           class<RocketProj> RocketClass,
                                           class<SeekingRocketProj> SeekingRocketClass)
{
    local RocketProj P;

    P = class'HxNet_RocketLauncher'.static.StaticSpawnProjectile(
                RocketLauncher(Weapon), Start, Dir, RocketClass, SeekingRocketClass);
    if (P != None)
    {
        P.Damage *= DamageAtten;
    }
    return P;
}

defaultproperties
{
    WeaponClass=class'RocketLauncher'
}
