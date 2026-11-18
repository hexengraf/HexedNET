class HxNet_RocketMultiFire extends RocketMultiFire
    DependsOn(HxNTWeapon);

var class<RocketProj> RocketClass;
var class<SeekingRocketProj> SeekingRocketClass;
var private float DelayedLoad;
#include Classes\Include\HxNTBaseProjectileFire.uci

function SaveDelayedState()
{
    DelayedLoad = Load;
}

function DoFireEffect()
{
    local Vector FireLocation;
    local Vector Start;
    local Vector X;
    local Vector Y;
    local Vector Z;
    local Rotator Aim;
    local array<RocketProj> FiredRockets;
    local bool bCurl;
    local float SavedLoad;
    local int SpawnCount;
    local int p;
    local int q;
    local int i;

    if (!WantsLagCompensation())
    {
        Super.DoFireEffect();
        return;
    }
    SavedLoad = Load;
    if (Level.NetMode == NM_Client)
    {
        if (bEarlyFireEffect)
        {
            if (RocketLauncher(Weapon).bTightSpread)
            {
                Spread = TightSpread;
                SpreadStyle = SS_Ring;
            }
            else
            {
                SpreadStyle = SS_Line;
                Spread = LooseSpread;
            }
        }
        if (bIsDelayed)
        {
            Load = DelayedLoad;
        }
    }
    if (SpreadStyle == SS_Line || Load < 2)
    {
        DoBaseFireEffect();
        Load = SavedLoad;
        return;
    }
    Instigator.MakeNoise(1.0);
    GetProjectileStartAndDirection(Start, Aim, X, Y, Z);
    SpawnCount = Max(1, int(Load));
    FiredRockets.Length = SpawnCount;
    if (Level.NetMode == NM_Client)
    {
        RocketClass = class'HxNet_RocketProjPredicted';
        SeekingRocketClass = class'HxNet_SeekingRocketProjPredicted';
    }
    else
    {
        RocketClass = class'HxNet_RocketProj';
        SeekingRocketClass = class'HxNet_SeekingRocketProj';
    }
    for (p = 0; p < SpawnCount; ++p)
    {
        FireLocation = Start - 2 * ((Sin(p * 2 * PI / MaxLoad) * 8 - 7) * Y
            - (Cos(p * 2 * PI / MaxLoad) * 8 - 7) * Z) - X * 8 * WeaponInfo.Generator.RandFloat();
        FiredRockets[p] = RocketProj(SpawnProjectile(FireLocation, Aim));
    }
    RocketClass = default.RocketClass;
    SeekingRocketClass = default.SeekingRocketClass;
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
    if (Level.NetMode == NM_Client)
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
            WeaponInfo.AddPredictedProjectile(FiredRockets[p]);
        }
        Load = SavedLoad;
    }
    else
    {
        for (p = 0; p < FiredRockets.Length; ++p)
        {
            if (HxNet_RocketProj(FiredRockets[p]) != None)
            {
                HxNet_RocketProj(FiredRockets[p]).Client = Client;
                HxNet_RocketProj(FiredRockets[p]).Index = p;
            }
            else if (HxNet_SeekingRocketProj(FiredRockets[p]) != None)
            {
                HxNet_SeekingRocketProj(FiredRockets[p]).Client = Client;
                HxNet_SeekingRocketProj(FiredRockets[p]).Index = p;
            }
            WeaponInfo.AssignUniqueID(FiredRockets[p]);
        }
        HexedNET.ForwardLinearProjectiles(Weapon, FiredRockets, GetCompensationTime());
    }
}

function Projectile SpawnHexedProjectile(Vector Start, Rotator Dir)
{
    local Projectile P;

    if (Level.NetMode == NM_Client)
    {
        RocketClass = class'HxNet_RocketProjPredicted';
        SeekingRocketClass = class'HxNet_SeekingRocketProjPredicted';
        P = SpawnProjectile(Start, Dir);
        if (P != None)
        {
            if (HxNet_RocketProjPredicted(P) != None)
            {
                HxNet_RocketProjPredicted(P).WeaponInfo = WeaponInfo;
            }
            else
            {
                HxNet_SeekingRocketProjPredicted(P).WeaponInfo = WeaponInfo;
            }
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
