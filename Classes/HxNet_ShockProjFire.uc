class HxNet_ShockProjFire extends ShockProjFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTBaseProjectileFire.uci

function SaveDelayedState();

function DoFireEffect()
{
    DoBaseFireEffect();
}

function Projectile SpawnHexedProjectile(Vector Start, Rotator Dir, optional int Index)
{
    local Projectile P;

    if (Level.NetMode == NM_Client)
    {
        ProjectileClass = class'HxNet_ShockProjectilePredicted';
        P = SpawnProjectile(Start, Dir);
        ProjectileClass = default.ProjectileClass;
        if (P != None)
        {
            HxNet_ShockProjectilePredicted(P).WeaponInfo = WeaponInfo;
        }
        return WeaponInfo.AddPredictedProjectile(P);
    }
    P = SpawnProjectile(Start, Dir);
    WeaponInfo.AssignUniqueID(P);
    if (P != None)
    {
        HxNet_ShockProjectile(P).Client = Client;
        HexedNET.ForwardLinearProjectile(Weapon, P, GetCompensationTime());
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
    WeaponClass=class'ShockRifle'
}
