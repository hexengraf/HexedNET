class NewNet_SniperFire extends SniperFire;

var bool bUseReplicatedInfo;
var rotator savedRot;
var vector savedVec;

var bool bSkipNextEffect;
var bool bBelievesHit;
var Actor BelievedHitActor;
var bool bFirstGo;

var private MutHexedNET HexedNET;
var private HxNTClient Client;

function PreBeginPlay()
{
    Super.PreBeginPlay();
    foreach Weapon.DynamicActors(class'MutHexedNET', HexedNET) break;
    class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client);
}

function bool IsEnhancedNetcodeEnabled()
{
    return class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        && Client.IsEnhancedNetcodeEnabled();
}

function PlayFiring()
{
    Super.PlayFiring();
    if (Level.NetMode == NM_Client && IsEnhancedNetcodeEnabled())
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

    if (!IsEnhancedNetcodeEnabled())
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
	local vector PresentHitLocation;
    local float PingDT;

	if (Level.NetMode == NM_Client || !IsEnhancedNetcodeEnabled())
	{
        super.DoTrace(Start,Dir);
        return;
    }
    pingDT = Client.AveragePing;
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

        if (bFirstGo && ArcsRemaining == NumArcs)
        {
            Other = HexedNET.CompensatedTrace2(
                PingDT,
                Weapon,
                PresentHitLocation,
                HitLocation,
                HitNormal,
                End,
                Start,
                bBelievesHit,
                BelievedHitActor);
        }
        else
        {
            Other = HexedNET.CompensatedTrace(
                PingDT, Weapon, PresentHitLocation, HitLocation, HitNormal, End, Start);
        }
        bFirstGo = false;

        if ( Other != None && (Other != Instigator || ReflectNum > 0) )
        {
            if (bReflective && Other.IsA('xPawn') && xPawn(Other).CheckReflect(PresentHitLocation, RefNormal, DamageMin*0.25))
            {
                bDoReflect = true;
            }
            else if ( Other != mainArcHitTarget )
            {
                if ( !Other.bWorldGeometry )
                {
                    Damage = (DamageMin + Rand(DamageMax - DamageMin)) * DamageAtten;

                    if (Vehicle(Other) != None)
                        HeadShotPawn = Vehicle(Other).CheckForHeadShot(PresentHitLocation, X, 1.0);

                    if (HeadShotPawn != None)
                        HeadShotPawn.TakeDamage(Damage * HeadShotDamageMult, Instigator, PresentHitLocation, Momentum*X, DamageTypeHeadShot);
					else if ( (Pawn(Other) != None) && (arcsRemaining == NumArcs)
						&& Pawn(Other).IsHeadShot(PresentHitLocation, X, 1.0) )
                        Other.TakeDamage(Damage * HeadShotDamageMult, Instigator, PresentHitLocation, Momentum*X, DamageTypeHeadShot);
                    else
                    {
						if ( arcsRemaining < NumArcs )
							Damage *= SecDamageMult;
                        Other.TakeDamage(Damage, Instigator, PresentHitLocation, Momentum*X, DamageType);
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
