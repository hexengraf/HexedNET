class HxNet_ShockBeamFire extends ShockBeamFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTBaseInstantFire.uci

function SpawnBeamEffect(Vector Start,
                         Rotator Dir,
                         Vector HitLocation,
                         Vector HitNormal,
                         int ReflectNum)
{
    if (Level.NetMode != NM_Client && ReflectNum == 0 && WantsLagCompensation())
    {
        BeamEffectClass = class'HxNet_ShockBeamEffect';
        Super.SpawnBeamEffect(Start, Dir, HitLocation, HitNormal, ReflectNum);
        BeamEffectClass = default.BeamEffectClass;
    }
    else
    {
        Super.SpawnBeamEffect(Start, Dir, HitLocation, HitNormal, ReflectNum);
    }
}

function DoTrace(Vector Start, Rotator Dir)
{
    if (WantsLagCompensation())
    {
        class'HxNTWeapon'.static.InstantFireTrace(
            HexedNET, Self, Start, Dir, GetCompensationTime(), ClientHit, bDoRecon);
    }
    else
    {
        Super.DoTrace(Start, Dir);
    }
}

function GetStartAndAim(out Vector Start, out Rotator Aim)
{
    local Vector X;
    local Vector Y;
    local Vector Z;

    Start = Instigator.Location + Instigator.EyePosition();
    Aim = AdjustAim(Start, AimError);
    Weapon.GetViewAxes(X, Y, Z);
    Start += X * class'ShockProjFire'.Default.ProjSpawnOffset.X;
    if (!Weapon.WeaponCentered())
    {
        Start += Weapon.Hand * Y * class'ShockProjFire'.Default.ProjSpawnOffset.Y
            + Z * class'ShockProjFire'.Default.ProjSpawnOffset.Z;
    }
}

function Rotator ApplySpread(Vector Aim)
{
    return Rotator(
        Aim + WeaponInfo.Generator.RandVect() * WeaponInfo.Generator.RandFloat() * Spread);
}

defaultproperties
{
    bClientFireEffect=true
    WeaponClass=class'ShockRifle'
}
