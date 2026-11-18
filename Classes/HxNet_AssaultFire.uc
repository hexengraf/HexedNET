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
            HexedNET, Self, Start, Dir, GetCompensationTime(), ClientHit, bDoRecon);
    }
}

function GetStartAndAim(out Vector Start, out Rotator Aim)
{
    Start = Instigator.Location + Instigator.EyePosition();
    Aim = AdjustAim(Start, AimError);
}

function Rotator ApplySpread(Vector Aim)
{
    local float ActualSpread;

    if (bEarlyFireEffect)
    {
        if (Level.TimeSeconds - LastFireTime > 0.5)
        {
            ActualSpread = Default.Spread;
        }
        else
        {
            ActualSpread = FMin(Spread + 0.02, 0.12);
        }
    }
    else
    {
        ActualSpread = Spread;
    }
    return Rotator(
        Aim + WeaponInfo.Generator.RandVect() * WeaponInfo.Generator.RandFloat() * ActualSpread);
}

defaultproperties
{
    bClientFireEffect=true
    WeaponClass=class'AssaultRifle'
}
