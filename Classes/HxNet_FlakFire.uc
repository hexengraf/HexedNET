class HxNet_FlakFire extends FlakFire
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
    local FlakChunk P;

    if (Level.NetMode == NM_Client)
    {
        ProjectileClass = class'HxNet_FlakChunkPredicted';
        P = FlakChunk(SpawnProjectile(Start, Dir));
        ProjectileClass = default.ProjectileClass;
        if (P != None)
        {
            HxNet_FlakChunkPredicted(P).WeaponInfo = WeaponInfo;
            P.Bounces = RandomizeBounces(WeaponInfo.Generator);
        }
        return WeaponInfo.TrackProjectile(P, Index);
    }
    if (WantsPingCompensation())
    {
        ProjectileClass = class'HxNet_FlakChunk';
        P = FlakChunk(SpawnProjectile(Start, Dir));
        ProjectileClass = default.ProjectileClass;
        if (P != None)
        {
            HxNet_FlakChunk(P).Client = Client;
            HxNet_FlakChunk(P).Index = Index;
            P.Bounces = RandomizeBounces(WeaponInfo.Generator);
            HexedNET.ForwardBouncingProjectile(Weapon, P, Client.GetProjectileCompensationTime() + ServerDelay);
        }
        return P;
    }
    return SpawnProjectile(Start, Dir);
}

final function int RandomizeBounces(HxRandomGenerator Generator)
{
    local float R;

    R = Generator.RandFloat();
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
