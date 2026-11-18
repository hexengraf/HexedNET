class HxNet_RocketFire extends RocketFire
    DependsOn(HxNTWeapon);

var class<RocketProj> RocketClass;
var class<SeekingRocketProj> SeekingRocketClass;
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
        RocketClass = class'HxNet_RocketProjPredicted';
        SeekingRocketClass = class'HxNet_SeekingRocketProjPredicted';
        P = SpawnProjectile(Start, Dir);
        if (HxNet_RocketProjPredicted(P) != None)
        {
            HxNet_RocketProjPredicted(P).WeaponInfo = WeaponInfo;
        }
        else if (HxNet_SeekingRocketProjPredicted(P) != None)
        {
            HxNet_SeekingRocketProjPredicted(P).WeaponInfo = WeaponInfo;
        }
        return WeaponInfo.AddPredictedProjectile(P);
    }
    RocketClass = class'HxNet_RocketProj';
    SeekingRocketClass = class'HxNet_SeekingRocketProj';
    P = WeaponInfo.AssignUniqueID(SpawnProjectile(Start, Dir));
    RocketClass = default.RocketClass;
    SeekingRocketClass = default.SeekingRocketClass;
    if (P != None)
    {
        if (HxNet_RocketProj(P) != None)
        {
            HxNet_RocketProj(P).Client = Client;
        }
        else
        {
            HxNet_SeekingRocketProj(P).Client = Client;
        }
        HexedNET.ForwardLinearProjectile(Weapon, P, GetCompensationTime());
    }
    return P;
}

function Projectile SpawnProjectile(Vector Start, Rotator Dir)
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
    RocketClass = class'RocketProj';
    SeekingRocketClass = class'SeekingRocketProj';
}
