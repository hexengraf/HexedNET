class HxNet_ZoomSuperShockBeamFire extends ZoomSuperShockBeamFire
    DependsOn(HxNTWeapon);

var bool bServerAllowMultiHit;
#include Classes\Include\HxNTBaseInstantFire.uci

function BeginPlay()
{
    Super.BeginPlay();
    if (bAllowMultiHit != class'ZoomSuperShockBeamFire'.default.bAllowMultiHit)
    {
        ClearConfig();
        default.bAllowMultiHit = class'ZoomSuperShockBeamFire'.default.bAllowMultiHit;
        bAllowMultiHit = default.bAllowMultiHit;
    }
}

function SpawnBeamEffect(Vector Start,
                         Rotator Dir,
                         Vector HitLocation,
                         Vector HitNormal,
                         int ReflectNum)
{
    local ShockBeamEffect Beam;

    if (Level.NetMode != NM_Client && WantsLagCompensation())
    {
        if (Weapon != None)
        {
            if (Instigator.PlayerReplicationInfo.Team != None
                && Instigator.PlayerReplicationInfo.Team.TeamIndex == 1)
            {
                Beam = Weapon.Spawn(class'HxNet_BlueSuperShockBeam', Weapon.Owner,, Start, Dir);
            }
            else
            {
                Beam = Weapon.Spawn(class'HxNet_SuperShockBeamEffect', Weapon.Owner,, Start, Dir);
            }
            if (ReflectNum != 0)
            {
                Beam.Instigator = None;
            }
            Beam.AimAt(HitLocation, HitNormal);
        }
    }
    else
    {
        Super.SpawnBeamEffect(Start, Dir, HitLocation, HitNormal, ReflectNum);
    }
}

function TracePart(Vector Start, Vector End, Vector X, Rotator Dir, Pawn Ignored)
{
    local float CompensationTime;

    if (!WantsLagCompensation())
    {
        Super.TracePart(Start, End, X, Dir, Ignored);
    }
    else if (HexedNET != None)
    {
        CompensationTime = Client.GetCompensationTime() + ServerDelay;
        if (ClientHit == None)
        {
            HexedNET.Rewind(CompensationTime);
            class'HxNet_SuperShockBeamFire'.static.StaticTracePart(
                HexedNET, Self, Start, End, X, Dir, Ignored, CompensationTime);
        }
        else
        {
            class'HxNet_SuperShockBeamFire'.static.StaticTracePart(
                HexedNET, Self, Start, End, X, Dir, Ignored, CompensationTime, ClientHit);
        }
        HexedNET.UndoRewind();
    }
    else
    {
        class'HxNet_SuperShockBeamFire'.static.StaticClientTracePart(
            Self, Start, End, X, Dir, Ignored);
    }
}

function bool AllowMultiHit()
{
    if (Level.NetMode == NM_Client)
    {
        return default.bServerAllowMultiHit;
    }
    return bAllowMultiHit;
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
