class HxNet_RocketFire extends RocketFire
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
        P = SpawnIndexedProjectile(
            Start, Dir, Index, class'HxNet_RocketProjDummy', class'HxNet_SeekingRocketProjDummy');
        return Client.TrackDummy(P, class'RocketLauncher');
    }
    if (WantsPingCompensation())
    {
        P = SpawnIndexedProjectile(
            Start, Dir, Index, class'HxNet_RocketProj', class'HxNet_SeekingRocketProj');
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
            HexedNET.ForwardLinearProjectile(Weapon, P, Client.GetProjectilePing() + ServerDelay);
        }
        return P;
    }
    return SpawnProjectile(Start, Dir);
}

function RocketProj SpawnIndexedProjectile(Vector Start,
                                           Rotator Dir,
                                           int Index,
                                           class<RocketProj> RocketClass,
                                           class<SeekingRocketProj> SeekingRocketClass)
{
    local RocketProj P;

    P = class'HxNet_RocketLauncher'.static.SpawnHexedProjectile(
                RocketLauncher(Weapon), Start, Dir, RocketClass, SeekingRocketClass);
    if (P != None)
    {
        P.Damage *= DamageAtten;
        P.SetPropertyText("Index", string(Index));
    }
    return P;
}

DefaultProperties
{
}
