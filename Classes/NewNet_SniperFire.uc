class NewNet_SniperFire extends SniperFire;

var bool bUseReplicatedInfo;
var rotator savedRot;
var vector savedVec;

var bool bSkipNextEffect;
//var bool bBelievesHit;
//var float Correct, Wrong;
//var bool bCount;
var bool bBelievesHit;
var Actor BelievedHitActor;
var vector BelievedHitLocation;
var float AverDT;
var bool bFirstGo;
//var vector BelievedHLDelta;

#include Classes\Include\WeaponFireBase.uci

function PlayFiring()
{
    Super.PlayFiring();
    if (class'HxNTClient'.static.IsEnhancedNetcodeEnabled(Level))
    {
        if (bSkipNextEffect)
        {
            bSkipNextEffect = false;
            Weapon.ClientStopFire(0);
        }
        else
        {
            CheckFireEffect();
        }
    }
}

function DoClientTrace(Vector Start, Rotator Dir)
{
    local Vector X,Y,Z, End, HitLocation, HitNormal, RefNormal;
    local Actor Other, mainArcHitTarget;
    local int ReflectNum, arcsRemaining;
    local bool bDoReflect;
    local class<Actor> tmpHitEmitClass;
    local float tmpTraceRange;
    local vector arcEnd, mainArcHit;
	local vector EffectOffset;

	if ( class'PlayerController'.Default.bSmallWeapons )
		EffectOffset = Weapon.SmallEffectOffset;
	else
		EffectOffset = Weapon.EffectOffset;

    Weapon.GetViewAxes(X, Y, Z);
    if ( Weapon.WeaponCentered() || SniperRifle(Weapon).zoomed )
        arcEnd = (Instigator.Location +
			EffectOffset.Z * Z);
	else if ( Weapon.Hand == 0 )
	{
		if ( class'PlayerController'.Default.bSmallWeapons )
			arcEnd = (Instigator.Location +
				EffectOffset.X * X);
		else
			arcEnd = (Instigator.Location +
				EffectOffset.X * X
				- 0.5 * EffectOffset.Z * Z);
	}
	else
        arcEnd = (Instigator.Location +
			Instigator.CalcDrawOffset(Weapon) +
			EffectOffset.X * X +
			Weapon.Hand * EffectOffset.Y * Y +
			EffectOffset.Z * Z);

    arcsRemaining = NumArcs;

    tmpHitEmitClass = HitEmitterClass;
    tmpTraceRange = TraceRange;

    ReflectNum = 0;
    while (true)
    {
        bDoReflect = false;
        X = Vector(Dir);
        End = Start + tmpTraceRange * X;
        Other = Weapon.Trace(HitLocation, HitNormal, End, Start, true);

        if ( Other != None && (Other != Instigator || ReflectNum > 0) )
        {
            if (bReflective && Other.IsA('xPawn') && xPawn(Other).CheckReflect(HitLocation, RefNormal, DamageMin*0.25))
            {
                bDoReflect = true;
            }
            else if ( Other != mainArcHitTarget )
            {
                if ( !Other.bWorldGeometry )
                {
                }
                else
					HitLocation = HitLocation + 2.0 * HitNormal;
            }
        }
        else
        {
            HitLocation = End;
            HitNormal = Normal(Start - End);
        }
        if ( Weapon == None )
			return;
        NewNet_SniperRifle(Weapon).SpawnLGEffect(tmpHitEmitClass, arcEnd, HitNormal, HitLocation);

		if ( HitScanBlockingVolume(Other) != None )
			return;

        if( arcsRemaining == NumArcs )
        {
            mainArcHit = HitLocation + (HitNormal * 2.0);
            if ( Other != None && !Other.bWorldGeometry )
                mainArcHitTarget = Other;
        }
        if (bDoReflect && ++ReflectNum < 4)
        {
            //Log("reflecting off"@Other@Start@HitLocation);
            Start = HitLocation;
            Dir = Rotator( X - 2.0*RefNormal*(X dot RefNormal) );
        }
        else if ( arcsRemaining > 0 )
        {
            arcsRemaining--;

            // done parent arc, now move trace point to arc trace hit location and try child arcs from there
            Start = mainArcHit;
            Dir = Rotator(VRand());
            tmpHitEmitClass = SecHitEmitterClass;
            tmpTraceRange = SecTraceDist;
            arcEnd = mainArcHit;
        }
        else
        {
            break;
        }
    }
}


function CheckFireEffect()
{
   if(Level.NetMode == NM_Client && Instigator.IsLocallyControlled())
   {
       DoFireEffect();
   }
}

function DoInstantFireEffect()
{
   if(Level.NetMode == NM_Client && Instigator.IsLocallyControlled())
   {
       DoFireEffect();
       bSkipNextEffect=true;
   }
}


function DoFireEffect()
{
    local Vector StartTrace;
    local Rotator R, Aim;

    if(!bUseEnhancedNetCode && Level.NetMode != NM_Client)
    {
        super.DoFireEffect();
        return;
    }

    Instigator.MakeNoise(1.0);

    if(bUseReplicatedInfo)
    {
        StartTrace=savedVec;
        R=SavedRot;
        bUseReplicatedInfo=false;

	}
    else
    {
        // the to-hit trace always starts right in front of the eye
        StartTrace = Instigator.Location + Instigator.EyePosition();
        Aim = AdjustAim(StartTrace, AimError);
	    R = rotator(vector(Aim) + VRand()*FRand()*Spread);
    }
    if(Level.NetMode == NM_Client)
        DoClientTrace(StartTrace, R);
    else
        DoTrace(StartTrace, R);
}

function DoTrace(Vector Start, Rotator Dir)
{
    local Vector X,Y,Z, End, HitLocation, HitNormal, RefNormal;
    local Actor Other, mainArcHitTarget;
    local int Damage, ReflectNum, arcsRemaining;
    local bool bDoReflect;
    local xEmitter hitEmitter;
    local class<Actor> tmpHitEmitClass;
    local float tmpTraceRange;
    local vector arcEnd, mainArcHit;
    local Pawn HeadShotPawn;
	local vector EffectOffset;
	local vector PawnHitLocation;

	local actor AltOther;
	local vector AltHitlocation,altHitNormal,altpawnhitlocation;
	local float f;

	if(!bUseEnhancedNetCode)
	{
        super.DoTrace(Start,Dir);
        return;
    }

    if ( class'PlayerController'.Default.bSmallWeapons )
		EffectOffset = Weapon.SmallEffectOffset;
	else
		EffectOffset = Weapon.EffectOffset;

    Weapon.GetViewAxes(X, Y, Z);
    if (Level.NetMode == NM_DedicatedServer) {
        arcEnd = (
            Instigator.Location +
            Instigator.BaseEyeHeight * vect(0,0,1) +
            EffectOffset.Z * Z +
            EffectOffset.Y * Y +
            EffectOffset.X * X
        );
    } else {
        if ( Weapon.WeaponCentered() || SniperRifle(Weapon).zoomed )
            arcEnd = (Instigator.Location +
                EffectOffset.Z * Z);
        else if ( Weapon.Hand == 0 )
        {
            if ( class'PlayerController'.Default.bSmallWeapons )
                arcEnd = (Instigator.Location +
                    EffectOffset.X * X);
            else
                arcEnd = (Instigator.Location +
                    EffectOffset.X * X
                    - 0.5 * EffectOffset.Z * Z);
        }
        else
            arcEnd = (Instigator.Location +
                Instigator.CalcDrawOffset(Weapon) +
                EffectOffset.X * X +
                Weapon.Hand * EffectOffset.Y * Y +
                EffectOffset.Z * Z);
    }

    arcsRemaining = NumArcs;

    tmpHitEmitClass = class'NewNet_NewLightningBolt';//HitEmitterClass;
    tmpTraceRange = TraceRange;

    ReflectNum = 0;

    HexedNET.TimeTravel(pingDT);

    while (true)
    {
        bDoReflect = false;
        X = Vector(Dir);
        End = Start + tmpTraceRange * X;

        if(PingDT <=0.0)
            Other = Weapon.Trace(HitLocation,HitNormal,End,Start,true);
        else
            Other = HexedNET.TimeTravelTrace(Weapon, HitLocation, HitNormal, End, Start);

        if(Other!=None && Other.IsA('PawnCollisionCopy'))
        {
            //Maintain the same ray, but move to the real pawn
            //ToDo: handle crouching differences
            PawnHitLocation = HitLocation + PawnCollisionCopy(Other).CopiedPawn.Location - Other.Location;
    /*        if(ArcsRemaining == NumArcs && bCount && bBelievesHit)
            {
                 PlayerController(Pawn(Weapon.Owner).Controller).ClientMessage(BelievedHLDelta - Other.Location);
                 bCount=false;
            }    */
            Other=PawnCollisionCopy(Other).CopiedPawn;

        }
        else
        {
            PawnHitLocation = HitLocation;
        }

        if(bFirstGo && bBelievesHit && !(Other == BelievedHitActor))
        {
            if(ArcsRemaining == NumArcs)
            {
                f = 0.02;
                while(abs(f) < (0.04 + 2.0*AverDT))
                {

                    HexedNET.TimeTravel(PingDT-f);
                    if((PingDT-f) <=0.0)
                          AltOther = Weapon.Trace(AltHitLocation,AltHitNormal,End,Start,true);
                    else
                          AltOther = HexedNET.TimeTravelTrace(Weapon, AltHitLocation, AltHitNormal, End, Start);

                    if(AltOther!=None && AltOther.IsA('PawnCollisionCopy'))
                    {
                         AltPawnHitLocation = AltHitLocation + PawnCollisionCopy(AltOther).CopiedPawn.Location - AltOther.Location;
                         AltOther=PawnCollisionCopy(AltOther).CopiedPawn;
                    }
                    else
                    {
                        AltPawnHitLocation=AltHitLocation;
                    }

                    if(altOther == BelievedHitACtor)
                    {
                    //   Log("Fixed At"@f@"with max"@(0.04 + 2.0*AverDT));
                       Other=altOther;
                       PawnHitLocation=AltPawnHitLocation;
                       HitLocation=AltHitLocation;
                       f=10.0;
                    }
                    if(f > 0.00)
                        f = -1.0*f;
                    else
                        f = -1.0*f+0.02;
                }
            //    if(abs(f)<9.0)
            //       log("Failed to fix");
            }
        }
        else if(bFirstGo && !bBelievesHit && Other!=None &&(Other.IsA('xpawn') || Other.IsA('Vehicle')))
        {
            if(ArcsRemaining == NumArcs)
            {
                f = 0.02;
                while(abs(f) < (0.04 + 2.0*AverDT))
                {
                    AltOther=None;
                    HexedNET.TimeTravel(PingDT-f);
                    if((PingDT-f) <=0.0)
                          AltOther = Weapon.Trace(AltHitLocation,AltHitNormal,End,Start,true);
                    else
                          AltOther = HexedNET.TimeTravelTrace(Weapon, AltHitLocation, AltHitNormal, End, Start);

                    if(AltOther!=None && AltOther.IsA('PawnCollisionCopy'))
                    {
                         AltPawnHitLocation = AltHitLocation + PawnCollisionCopy(AltOther).CopiedPawn.Location - AltOther.Location;
                         AltOther=PawnCollisionCopy(AltOther).CopiedPawn;
                    }
                    else
                    {
                         AltPAwnHitLocation=AltHitLocation;
                    }

                    if(altOther == None || !(altOther.IsA('xpawn') || altOther.IsA('Vehicle')))
                    {
                    //   Log("Reverse Fixed At"@f);
                       Other=altOther;
                       PawnHitLocation=AltPawnHitLocation;
                       HitLocation=AltHitLocation;
                       f=10.0;
                    }
                    if(f > 0.00)
                        f = -1.0*f;
                    else
                        f = -1.0*f+0.02;
                }
              //  if(abs(f)<9.0)
              //     log("Failed to reverse fix");
            }
        }
        bFirstGo=false;
       /* if(bCount && ArcsRemaining == NumArcs && Other.IsA('ShockProjectile'))
            bCount=false;

        if(ArcsRemaining == NumArcs && bCount)
        {
           if((bBelievesHit && Other.IsA('Xpawn'))
              Log(HitLocation -
            if((bBelievesHit && Other.IsA('Xpawn')) || (!bBelievesHit && (Other==None || !Other.IsA('xPawn'))) )
               default.Correct+=1.0;
            else
            {
               default.Wrong+=1.0;
               for(f=PingDT+0.13; f>=PingDt-0.13; f-=0.01)
               {
                  HexedNET.TimeTravel(f);
                  Other = HexedNET.TimeTravelTrace(Weapon, HitLocation, HitNormal, End, Start);
                  if(Other!=None && Other.IsA('PawnCollisionCopy'))
                  {
                        //Maintain the same ray, but move to the real pawn
                        //ToDo: handle crouching differences
                         PawnHitLocation = HitLocation + PawnCollisionCopy(Other).CopiedPawn.Location - Other.Location;
                         Other=PawnCollisionCopy(Other).CopiedPawn;
                  }
                  if((bBelievesHit && Other.IsA('Xpawn')) || (!bBelievesHit && (Other==None || !Other.IsA('xPawn'))) )
                  {
                      PlayerController(Pawn(Weapon.Owner).Controller).ClientMessage("Corrected error at"@f-Pingdt@"delta");
                  }
                  else
                  {
                      PlayerController(Pawn(Weapon.Owner).Controller).ClientMessage("couldn't fix at"@f-Pingdt@"delta"@Other);
                  }
               }
            }
            PlayerController(Pawn(Weapon.Owner).Controller).ClientMessage("Correct:"@default.Correct@"Wrong:"@default.Wrong);
            bCount=false;
        }      */

        if ( Other != None && (Other != Instigator || ReflectNum > 0) )
        {
            if (bReflective && Other.IsA('xPawn') && xPawn(Other).CheckReflect(PawnHitLocation, RefNormal, DamageMin*0.25))
            {
                bDoReflect = true;
            }
            else if ( Other != mainArcHitTarget )
            {
                if ( !Other.bWorldGeometry )
                {
                    Damage = (DamageMin + Rand(DamageMax - DamageMin)) * DamageAtten;

                    if (Vehicle(Other) != None)
                        HeadShotPawn = Vehicle(Other).CheckForHeadShot(PawnHitLocation, X, 1.0);

                    if (HeadShotPawn != None)
                        HeadShotPawn.TakeDamage(Damage * HeadShotDamageMult, Instigator, PawnHitLocation, Momentum*X, DamageTypeHeadShot);
					else if ( (Pawn(Other) != None) && (arcsRemaining == NumArcs)
						&& Pawn(Other).IsHeadShot(PawnHitLocation, X, 1.0) )
                        Other.TakeDamage(Damage * HeadShotDamageMult, Instigator, PawnHitLocation, Momentum*X, DamageTypeHeadShot);
                    else
                    {
						if ( arcsRemaining < NumArcs )
							Damage *= SecDamageMult;
                        Other.TakeDamage(Damage, Instigator, PawnHitLocation, Momentum*X, DamageType);
					}
                }
                else
					HitLocation = HitLocation + 2.0 * HitNormal;
            }
        }
        else
        {
            HitLocation = End;
            HitNormal = Normal(Start - End);
        }
        if ( Weapon == None )
			return;
        hitEmitter = xEmitter(Weapon.Spawn(tmpHitEmitClass,,, arcEnd, Rotator(HitNormal)));
        if ( hitEmitter != None )
			hitEmitter.mSpawnVecA = HitLocation;
		if ( HitScanBlockingVolume(Other) != None )
		{
        	HexedNET.UnTimeTravel();
            return;
        }

        if( arcsRemaining == NumArcs )
        {
            mainArcHit = HitLocation + (HitNormal * 2.0);
            if ( Other != None && !Other.bWorldGeometry )
                mainArcHitTarget = Other;
        }

        if (bDoReflect && ++ReflectNum < 4)
        {
            //Log("reflecting off"@Other@Start@HitLocation);
            Start = HitLocation;
            Dir = Rotator( X - 2.0*RefNormal*(X dot RefNormal) );
        }
        else if ( arcsRemaining > 0 )
        {
            arcsRemaining--;

            // done parent arc, now move trace point to arc trace hit location and try child arcs from there
            Start = mainArcHit;
            Dir = Rotator(VRand());
            tmpHitEmitClass = class'NewNet_ChildLightningBolt';//SecHitEmitterClass;
            tmpTraceRange = SecTraceDist;
            arcEnd = mainArcHit;
        }
        else
        {
            break;
        }
    }
    HexedNET.UnTimeTravel();
}

DefaultProperties
{
}
