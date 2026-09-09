class HxNet_RocketMultiFire extends RocketMultiFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTBaseProjectileFire.uci

function DoFireEffect()
{
    local class<RocketProj> RocketClass;
    local class<SeekingRocketProj> SeekingRocketClass;
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
        RocketClass = class'HxNet_RocketProjDummy';
        SeekingRocketClass = class'HxNet_SeekingRocketProjDummy';
    }
    Instigator.MakeNoise(1.0);
    GetProjectileStartAndDirection(Start, Aim, X, Y, Z);
    SpawnCount = Max(1, int(Load));
    FiredRockets.Length = SpawnCount;
    for (p = 0; p < SpawnCount; ++p)
    {
        FireLocation = Start - 2 * ((Sin(p * 2 * PI / MaxLoad) * 8 - 7) * Y
            - (Cos(p * 2 * PI / MaxLoad) * 8 - 7) * Z) - X * 8 * Client.GetRandomFloat();
        FiredRockets[p] = SpawnIndexedProjectile(
            FireLocation, Aim, p, RocketClass, SeekingRocketClass);
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
                if (Level.NetMode != NM_DedicatedServer)
                {
                    FiredRockets[p].SetTimer(0.1, true);
                }
            }
        }
    }
    if (HexedNET == None)
    {
        for (p = 0; p < SpawnCount; ++p)
        {
            Client.TrackDummyProjectile(FiredRockets[p], class'RocketLauncher');
        }
    }
    else if (WantsPingCompensation())
    {
        HexedNET.ForwardLinearProjectiles(
            Weapon, FiredRockets, Client.GetProjectilePing() + ServerDelay);
    }
}

function Projectile SpawnHexedProjectile(Vector Start, Rotator Dir, optional int Index)
{
    local Projectile P;

    if (Level.NetMode == NM_Client)
    {
        P = SpawnIndexedProjectile(
            Start, Dir, Index, class'HxNet_RocketProjDummy', class'HxNet_SeekingRocketProjDummy');
        return Client.TrackDummyProjectile(P, class'RocketLauncher');
    }
    if (WantsPingCompensation())
    {
        P = SpawnIndexedProjectile(
            Start, Dir, Index, class'HxNet_RocketProj', class'HxNet_SeekingRocketProj');
        if (P != None)
        {
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
