class HxNet_AssaultFire extends AssaultFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTBaseInstantFire.uci

function DoTrace(Vector Start, Rotator Dir)
{
    if (Level.NetMode == NM_Client || !WantsLagCompensation())
    {
        Super.DoTrace(Start, Dir);
    }
    else
    {
        class'HxNTWeapon'.static.InstantFireTrace(
            HexedNET, Self, Start, Dir, Client.GetCompensationTime() + ServerDelay, ClientHit);
    }
}

function GetStartAndAim(out Vector Start, out Rotator Aim)
{
    Start = Instigator.Location + Instigator.EyePosition();
    Aim = AdjustAim(Start, AimError);
}

defaultproperties
{
    BASLocationTolerance=360
    BASAngleTolerance=-0.5
    bClientFireEffect=true
}
