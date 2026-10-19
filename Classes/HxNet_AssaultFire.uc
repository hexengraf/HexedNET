class HxNet_AssaultFire extends AssaultFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTBaseInstantFire.uci

function DoFireEffect()
{
    if (bBoostedAimSynchronization)
    {
        Instigator.MakeNoise(1.0);
        DoTrace(BASStart, Rotator(Vector(BASAim) + VRand() * FRand() * Spread));
        bBoostedAimSynchronization = false;
    }
    else
    {
        Super.DoFireEffect();
    }
    ServerDelay = 0;
}

function DoTrace(Vector Start, Rotator Dir)
{
    if (Level.NetMode == NM_Client || !WantsLagCompensation())
    {
        Super.DoTrace(Start, Dir);
    }
    else
    {
        class'HxNTWeapon'.static.InstantFireTrace(
            HexedNET, Self, Start, Dir, Client.GetCompensationTime());
    }
}

defaultproperties
{
}
