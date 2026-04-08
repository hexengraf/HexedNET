class NewNet_SuperShockBeamFire extends SuperShockBeamFire;

#include Classes\Include\WeaponFireShockBeam.uci

function TracePart(Vector Start, Vector End, Vector X, Rotator Dir, Pawn Ignored)
{
    local Vector HitLocation, HitNormal;
    local Actor Other;
    local vector PawnHitLocation;
    local actor AltOther;
    local vector AltHitlocation,altHitNormal,altPawnHitLocation;
    local float f;

    if (!bUseEnhancedNetCode)
    {
        Super.TracePart(Start, End, X, Dir, Ignored);
        return;
    }
    HexedNET.TimeTravel(pingDT);
    if (PingDT <= 0.0)
    {
        Other = Weapon.Trace(HitLocation, HitNormal, End, Start, true);
    }
    else
    {
        Other = HexedNET.TimeTravelTrace(Weapon, HitLocation, HitNormal, End, Start);
    }
    if (Other != None && Other.IsA('PawnCollisionCopy'))
    {
        PawnHitLocation =
            HitLocation + PawnCollisionCopy(Other).CopiedPawn.Location - Other.Location;
        Other = PawnCollisionCopy(Other).CopiedPawn;
    }
    else
    {
        PawnHitLocation = HitLocation;
    }
    if (bFirstGo)
    {
        f = 0.02;
        if (bBelievesHit && Other != BelievedHitActor)
        {
            while (Abs(f) < 0.04 + (2.0 * AverDT))
            {
                HexedNET.TimeTravel(PingDT-f);
                if ((PingDT-f) <= 0.0)
                {
                    AltOther = Weapon.Trace(AltHitLocation,AltHitNormal,End,Start,true);
                }
                else
                {
                    AltOther = HexedNET.TimeTravelTrace(
                        Weapon, AltHitLocation, AltHitNormal, End, Start);
                }
                if (AltOther != None && AltOther.IsA('PawnCollisionCopy'))
                {
                    AltPawnHitLocation =
                        AltHitLocation + PawnCollisionCopy(AltOther).CopiedPawn.Location
                        - AltOther.Location;
                    AltOther = PawnCollisionCopy(AltOther).CopiedPawn;
                }
                else
                {
                    AltPawnHitLocation = AltHitLocation;
                }
                if (AltOther == BelievedHitACtor)
                {
                    // Log("Fixed At"@f@"with max"@(0.04 + 2.0*AverDT));
                    Other = AltOther;
                    PawnHitLocation = AltPawnHitLocation;
                    HitLocation = AltHitLocation;
                    f = 10.0;
                }
                if (f > 0.00)
                {
                    f = -1.0 * f;
                }
                else
                {
                    f = -1.0 * f + 0.02;
                }
            }
            // if (abs(f) < 9.0) log("Failed to fix");
        }
        else if (!bBelievesHit && Other != None && (Other.IsA('xPawn') || Other.IsA('Vehicle')))
        {
            while (Abs(f) < 0.04 + (2.0 * AverDT))
            {
                AltOther = None;
                HexedNET.TimeTravel(PingDT - f);
                if ((PingDT - f) <= 0.0)
                {
                    AltOther = Weapon.Trace(AltHitLocation, AltHitNormal, End, Start, true);
                }
                else
                {
                    AltOther = HexedNET.TimeTravelTrace(
                        Weapon, AltHitLocation, AltHitNormal, End, Start);
                }
                if (AltOther != None && AltOther.IsA('PawnCollisionCopy'))
                {
                    AltPawnHitLocation =
                        AltHitLocation + PawnCollisionCopy(AltOther).CopiedPawn.Location
                        - AltOther.Location;
                    AltOther = PawnCollisionCopy(AltOther).CopiedPawn;
                }
                else
                {
                    AltPawnHitLocation = AltHitLocation;
                }
                if (AltOther == None || !(AltOther.IsA('xPawn') || AltOther.IsA('Vehicle')))
                {
                    // Log("Reverse Fixed At"@f);
                    Other = AltOther;
                    PawnHitLocation = AltPawnHitLocation;
                    HitLocation = AltHitLocation;
                    f=10.0;
                }
                if(f > 0.00)
                {
                    f = -1.0 * f;
                }
                else
                {
                    f = -1.0 * f + 0.02;
                }
            }
            // if (abs(f) < 9.0) log("Failed to reverse fix");
        }
        bFirstGo = false;
    }
    HexedNET.UnTimeTravel();

    if (Other != None && Other != Ignored)
    {
        if (!Other.bWorldGeometry)
        {
            Other.TakeDamage(DamageMax, Instigator, PawnHitLocation, Momentum*X, DamageType);
            HitNormal = vect(0,0,0);
            if (Pawn(Other) != None && HitLocation != Start && AllowMultiHit())
            {
				TracePart(HitLocation, End, X, Dir, Pawn(Other));
            }
        }
    }
    else
    {
        HitLocation = End;
        HitNormal = vect(0,0,0);
    }
    SpawnBeamEffect(Start, Dir, HitLocation, HitNormal, 0);
}

function DoClientTrace(Vector Start, Rotator Dir)
{
	local Vector X;

	X = vector(Dir);
	ClientTracePart(Start, Start + X * TraceRange, X, Dir, Instigator);
}

function ClientTracePart(Vector Start, Vector End, Vector X, Rotator Dir, Pawn Ignored)
{
    local Vector HitLocation, HitNormal;
    local Actor Other;

    Other = Ignored.Trace(HitLocation, HitNormal, End, Start, true);

    if (Other != None && Other != Ignored)
    {
        if (!Other.bWorldGeometry)
        {
            HitNormal = Vect(0,0,0);
            if (Pawn(Other) != None && HitLocation != Start && AllowMultiHit())
            {
				ClientTracePart(HitLocation, End, X, Dir, Pawn(Other));
            }
        }
    }
    else
    {
        HitLocation = End;
        HitNormal = Vect(0,0,0);
    }
    SpawnBeamEffect(Start, Dir, HitLocation, HitNormal, 0);
}

function ShockBeamEffect NewNet_SpawnBeamEffect(Vector Start, Rotator Dir)
{
    if (Instigator.PlayerReplicationInfo.Team != None
        && Instigator.PlayerReplicationInfo.Team.TeamIndex == 1)
    {
        return Weapon.Spawn(class'NewNet_BlueSuperShockBeam', Weapon.Owner,, Start, Dir);
    }
    return Weapon.Spawn(class'NewNet_SuperShockBeamEffect', Weapon.Owner,, Start, Dir);
}

DefaultProperties
{
}
