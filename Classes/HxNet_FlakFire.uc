class HxNet_FlakFire extends FlakFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTBaseProjectileFire.uci

function DoFireEffect()
{
    DoBaseFireEffect();
}
function Projectile SpawnHexedProjectile(Vector Start, Rotator Dir, optional int Index)
{
    local HxNet_FlakChunkDummy Dummy;
    local HxNet_FlakChunk P;

    if (Level.NetMode == NM_Client)
    {
        ProjectileClass = class'HxNet_FlakChunkDummy';
        Dummy = HxNet_FlakChunkDummy(SpawnProjectile(Start, Dir));
        ProjectileClass = default.ProjectileClass;
        if (Dummy != None)
        {
            Dummy.Index = Index;
            Dummy.Bounces = RandomizeBounces();
        }
        return Client.TrackDummyProjectile(Dummy, class'FlakCannon');
    }
    if (WantsPingCompensation())
    {
        P = HxNet_FlakChunk(SpawnProjectile(Start, Dir));
        if (P != None)
        {
            P.Index = Index;
            P.Bounces = RandomizeBounces();
        }
        HexedNET.ForwardBouncingProjectile(Weapon, P, Client.GetProjectilePing() + ServerDelay);
        return P;
    }
    return SpawnProjectile(Start, Dir);
}

final function int RandomizeBounces()
{
    local float R;

    R = Client.GetRandomFloat();
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
    ProjectileClass=class'HxNet_FlakChunk'
}
