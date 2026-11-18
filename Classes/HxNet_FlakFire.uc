class HxNet_FlakFire extends FlakFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTBaseProjectileFire.uci

function SaveDelayedState();

function DoFireEffect()
{
    DoBaseFireEffect();
}
function Projectile SpawnHexedProjectile(Vector Start, Rotator Dir)
{
    local FlakChunk P;

    if (Level.NetMode == NM_Client)
    {
        ProjectileClass = class'HxNet_FlakChunkPredicted';
        P = FlakChunk(SpawnProjectile(Start, Dir));
        if (P != None)
        {
            HxNet_FlakChunkPredicted(P).WeaponInfo = WeaponInfo;
            P.Bounces = RandomizeBounces();
        }
        return WeaponInfo.AddPredictedProjectile(P);
    }
    ProjectileClass = class'HxNet_FlakChunk';
    P = FlakChunk(WeaponInfo.AssignUniqueID(SpawnProjectile(Start, Dir)));
    ProjectileClass = default.ProjectileClass;
    if (P != None)
    {
        HxNet_FlakChunk(P).Client = Client;
        P.Bounces = RandomizeBounces();
        HexedNET.ForwardBouncingProjectile(Weapon, P, GetCompensationTime());
    }
    return P;
}

function int RandomizeBounces()
{
    local float R;

    R = WeaponInfo.Generator.RandFloat();
    if (R > 0.75)
    {
        return 2;
    }
    if (R > 0.25)
    {
        return 1;
    }
    return 0;
}

defaultproperties
{
    WeaponClass=class'FlakCannon'
}
