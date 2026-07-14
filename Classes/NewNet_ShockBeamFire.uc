class NewNet_ShockBeamFire extends ShockBeamFire;

var bool bUseReplicatedInfo;
var rotator SavedRot;
var vector SavedVec;

var bool bSkipNextEffect;
var int bSkipNextEffectMode;
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
            Weapon.ClientStopFire(bSkipNextEffectMode);
        }
        else
        {
            CheckFireEffect();
        }
    }
}

function CheckFireEffect()
{
   if (Level.NetMode == NM_Client && Instigator.IsLocallyControlled())
   {
       DoFireEffect();
   }
}

function DoInstantFireEffect(int Mode)
{
   if (Level.NetMode == NM_Client && Instigator.IsLocallyControlled())
   {
       DoFireEffect();
       bSkipNextEffectMode = Mode;
       bSkipNextEffect = true;
   }
}

function DoFireEffect()
{
    local vector StartTrace;
    local rotator R;
    local rotator Aim;

    if (!IsEnhancedNetcodeEnabled())
    {
        Super.DoFireEffect();
        return;
    }

    Instigator.MakeNoise(1.0);
    if (bUseReplicatedInfo)
    {
        StartTrace=SavedVec;
        R=SavedRot;
        bUseReplicatedInfo=false;
	}
    else
    {
        // the to-hit trace always starts right in front of the eye
        StartTrace = Instigator.Location + Instigator.EyePosition();
        Aim = AdjustAim(StartTrace, AimError);
	    R = rotator(vector(Aim) + VRand() * FRand() * Spread);
    }
    if (Level.NetMode == NM_Client)
    {
        DoClientTrace(StartTrace, R);
    }
    else
    {
        DoTrace(StartTrace, R);
    }
}

function SpawnBeamEffect(vector Start,
                         rotator Dir,
                         vector HitLocation,
                         vector HitNormal,
                         int ReflectNum)
{
    local ShockBeamEffect Beam;

    if (Level.NetMode != NM_Client && IsEnhancedNetcodeEnabled())
    {
        if (Weapon != None)
        {
            Beam = NewNet_SpawnBeamEffect(Start, Dir);
            if (Beam != None)
            {
                if (ReflectNum != 0)
                {
                    // prevents client side repositioning of beam start
                    Beam.Instigator = None;
                }
                Beam.AimAt(HitLocation, HitNormal);
            }
        }
    }
    else
    {
        Super.SpawnBeamEffect(Start, Dir, HitLocation, HitNormal, ReflectNum);
    }
}

function DoTrace(vector Start, rotator Dir)
{
    local Actor Other;
    local vector X;
    local vector End;
    local vector HitLocation;
    local vector HitNormal;
    local vector RefNormal;
    local vector PresentHitLocation;
    local int Damage;
    local bool bDoReflect;
    local int ReflectNum;
    local float PingDT;

    if (Level.NetMode == NM_Client || !IsEnhancedNetcodeEnabled())
    {
        Super.DoTrace(Start, Dir);
        return;
    }
    PingDT = Client.AveragePing;
    MaxRange();
    ReflectNum = 0;
    while (true)
    {
        bDoReflect = false;
        X = vector(Dir);
        End = Start + TraceRange * X;
        HexedNET.TimeTravel(pingDT);
        if (bFirstGo)
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
            bFirstGo = false;
        }
        else
        {
            Other = HexedNET.CompensatedTrace(
                PingDT, Weapon, PresentHitLocation, HitLocation, HitNormal, End, Start);
        }
        HexedNET.UnTimeTravel();

        if (Other != None && (Other != Instigator || ReflectNum > 0))
        {
            if (bReflective && Other.IsA('xPawn')
                && xPawn(Other).CheckReflect(PresentHitLocation, RefNormal, DamageMin * 0.25))
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
                        Other, PresentHitLocation, HitNormal);
                }
                Other.TakeDamage(Damage, Instigator, PresentHitLocation, Momentum * X, DamageType);
                HitNormal = Vect(0,0,0);
            }
            else if (WeaponAttachment(Weapon.ThirdPersonActor) != None)
            {
                WeaponAttachment(Weapon.ThirdPersonActor).UpdateHit(
                    Other, PresentHitLocation, HitNormal);
            }
        }
        else
        {
            HitLocation = End;
            HitNormal = Vect(0,0,0);
            WeaponAttachment(Weapon.ThirdPersonActor).UpdateHit(Other, PresentHitLocation, HitNormal);
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
