class HxNet_RocketMultiFire extends RocketMultiFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTBaseProjectileFire.uci

function DoFireEffect()
{
    local class<RocketProj> RocketClass;
    local class<SeekingRocketProj> SeekingRocketClass;
    local HxNTWeaponInfo WeaponInfo;
    local Vector FireLocation;
    local Vector Start;
    local Vector X;
    local Vector Y;
    local Vector Z;
    local Rotator Aim;
    local array<RocketProj> FiredRockets;
    local bool bCurl;
    local int SpawnCount;
    local int p;
    local int q;
    local int i;

    if (!class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client))
    {
        Super.DoFireEffect();
        return;
    }
    if (SpreadStyle == SS_Line || Load < 2)
    {
        DoBaseFireEffect();
        return;
    }
    if (HexedNET != None)
    {
        RocketClass = class'HxNet_RocketProj';
        SeekingRocketClass = class'HxNet_SeekingRocketProj';
    }
    else
    {
        RocketClass = class'HxNet_RocketProjPredicted';
        SeekingRocketClass = class'HxNet_SeekingRocketProjPredicted';
    }
    Instigator.MakeNoise(1.0);
    GetProjectileStartAndDirection(Start, Aim, X, Y, Z);
    SpawnCount = Max(1, int(Load));
    FiredRockets.Length = SpawnCount;
    WeaponInfo = Client.GetWeaponInfo(WeaponClass);
    for (p = 0; p < SpawnCount; ++p)
    {
        FireLocation = Start - 2 * ((Sin(p * 2 * PI / MaxLoad) * 8 - 7) * Y
            - (Cos(p * 2 * PI / MaxLoad) * 8 - 7) * Z) - X * 8 * WeaponInfo.Generator.RandFloat();
        FiredRockets[p] = SpawnIndexedProjectile(
            FireLocation, Aim, RocketClass, SeekingRocketClass);
    }
    if (SpawnCount > 1)
    {
        ++FlockIndex;
        if (FlockIndex == 0)
        {
            FlockIndex = 1;
        }
        for (p = 0; p < SpawnCount; ++p)
        {
            if (FiredRockets[p] != None)
            {
                FiredRockets[p].bCurl = bCurl;
                FiredRockets[p].FlockIndex = FlockIndex;
                i = 0;
                for (q = 0; q < SpawnCount; ++q)
                {
                    if (p != q && FiredRockets[q] != None)
                    {
                        FiredRockets[p].Flock[i] = FiredRockets[q];
                        i++;
                    }
                }
                bCurl = !bCurl;
                FiredRockets[p].SetTimer(0.1, true);
            }
        }
    }
    if (HexedNET == None)
    {
        for (p = 0; p < SpawnCount; ++p)
        {
            if (HxNet_RocketProjPredicted(FiredRockets[p]) != None)
            {
                HxNet_RocketProjPredicted(FiredRockets[p]).WeaponInfo = WeaponInfo;
            }
            else if (HxNet_SeekingRocketProjPredicted(FiredRockets[p]) != None)
            {
                HxNet_SeekingRocketProjPredicted(FiredRockets[p]).WeaponInfo = WeaponInfo;
            }
            WeaponInfo.TrackProjectile(FiredRockets[p], p);
        }
    }
    else if (WantsPingCompensation())
    {
        for (p = 0; p < FiredRockets.Length; ++p)
        {
            if (HxNet_RocketProj(FiredRockets[p]) != None)
            {
                HxNet_RocketProj(FiredRockets[p]).Client = Client;
            }
            else if (HxNet_SeekingRocketProj(FiredRockets[p]) != None)
            {
                HxNet_SeekingRocketProj(FiredRockets[p]).Client = Client;
            }
        }
        HexedNET.ForwardLinearProjectiles(
            Weapon, FiredRockets, Client.GetProjectilePing() + ServerDelay);
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
            HexedNET.ForwardLinearProjectile(Weapon, P, Client.GetProjectilePing() + ServerDelay);
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
