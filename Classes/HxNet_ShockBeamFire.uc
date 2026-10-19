class HxNet_ShockBeamFire extends ShockBeamFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTBaseInstantFire.uci

function DoFireEffect()
{
    local Vector X;
    local Vector Y;
    local Vector Z;

    if (bBoostedAimSynchronization)
    {
        if (PlayerController(Instigator.Controller) != None)
        {
            GetAxes(BASAim, X, Y, Z);
            BASStart += X * class'ShockProjFire'.Default.ProjSpawnOffset.X;
            if (!Weapon.WeaponCentered())
            {
                BASStart += Weapon.Hand * Y * class'ShockProjFire'.Default.ProjSpawnOffset.Y
                    + Z * class'ShockProjFire'.Default.ProjSpawnOffset.Z;
            }
        }
        Instigator.MakeNoise(1.0);
        DoTrace(BASStart, BASAim);
        bBoostedAimSynchronization = false;
    }
    else
    {
        Super.DoFireEffect();
    }
    ServerDelay = 0;
}

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
            HexedNET, Self, Start, Dir, Client.GetCompensationTime() + ServerDelay);
    }
    else
    {
        Super.DoTrace(Start, Dir);
    }
}

defaultproperties
{
}
