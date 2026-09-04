class HxNet_ShockProjFire extends ShockProjFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTBaseProjectileFire.uci

function DoFireEffect()
{
    DoBaseFireEffect();
}

function Projectile SpawnHexedProjectile(Vector Start, Rotator Dir, optional int Index)
{
    local Projectile P;
    local float DeltaTime;

    if (Level.NetMode == NM_Client)
    {
        ProjectileClass = class'HxNet_ShockProjectileDummy';
        P = SpawnProjectile(Start, Dir);
        ProjectileClass = default.ProjectileClass;
        return Client.TrackDummyProjectile(P, class'ShockRifle');
    }
    P = SpawnProjectile(Start, Dir);
    if (IsEnhancedNetcodeEnabled())
    {
        DeltaTime = Client.GetProjectilePing() + ServerDelay;
        HexedNET.ExtrapolateLinearProjectile(Weapon, P, DeltaTime);
        if (P != None)
        {
            P.SetTimer(FMax(0, P.TimerRate - DeltaTime), false);
        }
    }
    if (HexedNET != None)
    {
        HexedNET.RegisterShockProjectile(HxNet_ShockProjectile(P));
    }
    return P;
}

defaultproperties
{
    ProjectileClass=class'HxNet_ShockProjectile'
}
