class HxNet_AssaultFire extends AssaultFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTBaseInstantFire.uci

function DoTrace(Vector Start, Rotator Dir)
{
    local float CompensationTime;

    if (Level.NetMode == NM_Client || !WantsLagCompensation())
    {
        Super.DoTrace(Start, Dir);
    }
    else
    {
        CompensationTime = Client.GetCompensationTime() + ServerDelay;
        class'HxNTWeapon'.static.InstantFireTrace(
            HexedNET, Self, Start, Dir, CompensationTime, ClientHit, bDoRecon);
    }
}

function GetStartAndAim(out Vector Start, out Rotator Aim)
{
    Start = Instigator.Location + Instigator.EyePosition();
    Aim = AdjustAim(Start, AimError);
}

defaultproperties
{
    BASLocationTolerance=1250
    BASAngleTolerance=-0.5
    bClientFireEffect=true
}
