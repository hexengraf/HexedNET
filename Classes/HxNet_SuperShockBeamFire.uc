class HxNet_SuperShockBeamFire extends SuperShockBeamFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTBaseInstantFire.uci

function SpawnBeamEffect(Vector Start,
                         Rotator Dir,
                         Vector HitLocation,
                         Vector HitNormal,
                         int ReflectNum)
{
    local ShockBeamEffect Beam;

    if (Level.NetMode != NM_Client && WantsLagCompensation())
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
            StaticTracePart(HexedNET, Self, Start, End, X, Dir, Ignored, CompensationTime);
        }
        else
        {
            StaticTracePart(
                HexedNET, Self, Start, End, X, Dir, Ignored, CompensationTime, ClientHit);
        }
        HexedNET.UndoRewind();
    }
    else
    {
        StaticClientTracePart(Self, Start, End, X, Dir, Ignored);
    }
}

static function StaticTracePart(MutHexedNET HexedNET,
                                SuperShockBeamFire WF,
                                Vector Start,
                                Vector End,
                                Vector X,
                                Rotator Dir,
                                Pawn Ignored,
                                float CompensationTime,
                                optional Actor ClientHit)
{
    local Vector HitLocation;
    local Vector PastLocation;
    local Vector HitNormal;
    local Actor Hit;

    if (ClientHit != None)
    {
        Hit = HexedNET.ReconTrace(
            WF.Weapon,
            HitLocation,
            HitNormal,
            End,
            Start,
            CompensationTime,
            ClientHit,
            PastLocation);
    }
    else
    {
        Hit = HexedNET.RewoundTrace(WF.Weapon, HitLocation, HitNormal, End, Start,,, PastLocation);
    }
    if (Hit != None && Hit != Ignored)
    {
        if (!Hit.bWorldGeometry)
        {
            Hit.TakeDamage(
                WF.DamageMax, WF.Instigator, HitLocation, WF.Momentum * X, WF.DamageType);
            HitNormal = Vect(0, 0, 0);
            if (Pawn(Hit) != None && HitLocation != Start && WF.AllowMultiHit())
            {
                StaticTracePart(
                    HexedNET, WF, PastLocation, End, X, Dir, Pawn(Hit), CompensationTime);
            }
        }
    }
    else
    {
        HitLocation = End;
        HitNormal = Vect(0, 0, 0);
    }
    WF.SpawnBeamEffect(Start, Dir, HitLocation, HitNormal, 0);
}

static function StaticClientTracePart(SuperShockBeamFire WF,
                                      Vector Start,
                                      Vector End,
                                      Vector X,
                                      Rotator Dir,
                                      Pawn Ignored)
{
    local Vector HitLocation;
    local Vector HitNormal;
    local Actor Hit;

    Hit = Ignored.Trace(HitLocation, HitNormal, End, Start, true);
    if (Hit != None && Hit != Ignored)
    {
        if (!Hit.bWorldGeometry)
        {
            HitNormal = Vect(0, 0, 0);
            if (Pawn(Hit) != None && HitLocation != Start && WF.AllowMultiHit())
            {
                StaticClientTracePart(WF, HitLocation, End, X, Dir, Pawn(Hit));
            }
        }
    }
    else
    {
        HitLocation = End;
        HitNormal = Vect(0, 0, 0);
    }
    WF.SpawnBeamEffect(Start, Dir, HitLocation, HitNormal, 0);
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
