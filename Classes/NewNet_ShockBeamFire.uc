class NewNet_ShockBeamFire extends ShockBeamFire;

#include Classes\Include\WeaponFireShockBeam.uci

function DoTrace(vector Start, rotator Dir)
{
    local vector X, End, HitLocation, HitNormal, RefNormal;
    local Actor Other;
    local int Damage;
    local bool bDoReflect;
    local int ReflectNum;
    local vector PawnHitLocation;
    local actor AltOther;
    local vector AltHitlocation,altHitNormal,altPawnHitLocation;
    local float f;
    // local vector ShockLoc;

    if (!bUseEnhancedNetCode)
    {
        Super.DoTrace(Start, Dir);
        return;
    }
    MaxRange();
    ReflectNum = 0;
    while (true)
    {
        HexedNET.TimeTravel(pingDT);
        bDoReflect = false;
        X = vector(Dir);
        End = Start + TraceRange * X;
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
        if (bFirstGo && bBelievesHit && Other != BelievedHitActor)
        {
            if (ReflectNum == 0)
            {
                f = 0.02;
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
        }
        else if (bFirstGo && !bBelievesHit && Other != None
            && (Other.IsA('xPawn') || Other.IsA('Vehicle')))
        {
            if (ReflectNum == 0)
            {
                f = 0.02;
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
        }
        bFirstGo = false;
        HexedNET.UnTimeTravel();

        if (Other != None && (Other != Instigator || ReflectNum > 0))
        {
            if (bReflective && Other.IsA('xPawn')
                && xPawn(Other).CheckReflect(PawnHitLocation, RefNormal, DamageMin * 0.25))
            {
                bDoReflect = true;
                HitNormal = Vect(0,0,0);
            }
            else if (!Other.bWorldGeometry)
            {
                Damage = DamageMin;
                if (DamageMin != DamageMax && (FRand() > 0.5))
                {
                    Damage += Rand(1 + DamageMax - DamageMin);
                }
                Damage = Damage * DamageAtten;
                // Update hit effect except for pawns (blood) other than vehicles.
                if (Other.IsA('Vehicle')
                    || (!Other.IsA('Pawn') && !Other.IsA('HitScanBlockingVolume')))
                {
                    WeaponAttachment(Weapon.ThirdPersonActor).UpdateHit(
                        Other, PawnHitLocation, HitNormal);
                }
                Other.TakeDamage(Damage, Instigator, PawnHitLocation, Momentum * X, DamageType);
                HitNormal = Vect(0,0,0);
            }
            else if (WeaponAttachment(Weapon.ThirdPersonActor) != None)
            {
                WeaponAttachment(Weapon.ThirdPersonActor).UpdateHit(
                    Other, PawnHitLocation, HitNormal);
            }
        }
        else
        {
            HitLocation = End;
            HitNormal = Vect(0,0,0);
            WeaponAttachment(Weapon.ThirdPersonActor).UpdateHit(Other, PawnHitLocation, HitNormal);
        }
        SpawnBeamEffect(Start, Dir, HitLocation, HitNormal, ReflectNum);

        if (bDoReflect && ++ReflectNum < 4)
        {
            //Log("reflecting off"@Other@Start@HitLocation);
            Start = HitLocation;
            Dir = rotator(RefNormal); //rotator( X - 2.0*RefNormal*(X dot RefNormal) );
        }
        else
        {
            break;
        }
    }
}

simulated function DoClientTrace(vector Start, rotator Dir)
{
    local vector End;
    local vector HitLocation;
    local vector HitNormal;
    local vector RefNormal;
    local Actor Other;
    local bool bDoReflect;
    local int ReflectNum;

	MaxRange();
    ReflectNum = 0;
    while (true)
    {
        bDoReflect = false;
        // X = vector(Dir);
        End = Start + TraceRange * vector(Dir);
        Other = Weapon.Trace(HitLocation, HitNormal, End, Start, true);
        if (Other != None && (Other != Instigator || ReflectNum > 0))
        {
            if (bReflective && Other.IsA('xPawn')
                && xPawn(Other).CheckReflect(HitLocation, RefNormal, DamageMin * 0.25))
            {
                bDoReflect = true;
                HitNormal = Vect(0,0,0);
            }
            else if (!Other.bWorldGeometry)
            {
				// Update hit effect except for pawns (blood) other than vehicles.
               	if (WeaponAttachment(Weapon.ThirdPersonActor) != None && (Other.IsA('Vehicle')
                    || (!Other.IsA('Pawn') && !Other.IsA('HitScanBlockingVolume'))))
                {
					WeaponAttachment(Weapon.ThirdPersonActor).UpdateHit(
                        Other, HitLocation, HitNormal);
                }
                HitNormal = Vect(0,0,0);
            }
            else if (WeaponAttachment(Weapon.ThirdPersonActor) != None)
            {
				WeaponAttachment(Weapon.ThirdPersonActor).UpdateHit(Other,HitLocation,HitNormal);
            }
        }
        else
        {
            HitLocation = End;
            HitNormal = Vect(0,0,0);
            if (WeaponAttachment(Weapon.ThirdPersonActor) != None)
            {
                WeaponAttachment(Weapon.ThirdPersonActor).UpdateHit(Other,HitLocation,HitNormal);
            }
        }
        Super.SpawnBeamEffect(Start, Dir, HitLocation, HitNormal, ReflectNum);
        if (bDoReflect && ++ReflectNum < 4)
        {
            //Log("reflecting off"@Other@Start@HitLocation);
            Start = HitLocation;
            Dir = rotator(RefNormal); //rotator( X - 2.0*RefNormal*(X dot RefNormal) );
        }
        else
        {
            break;
        }
    }
}

function ShockBeamEffect NewNet_SpawnBeamEffect(Vector Start, Rotator Dir)
{
    return  Weapon.Spawn(Class'NewNet_ShockBeamEffect', Weapon.Owner,, Start, Dir);
}

DefaultProperties
{
}
