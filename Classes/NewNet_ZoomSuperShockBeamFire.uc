class NewNet_ZoomSuperShockBeamFire extends ZoomSuperShockBeamFire;

var bool bServerAllowMultiHit;

var bool bUseReplicatedInfo;
var rotator SavedRot;
var vector SavedVec;

var bool bSkipNextEffect;
var int bSkipNextEffectMode;
var bool bBelievesHit;
var Actor BelievedHitActor;
var byte FirstGo;

var private MutHexedNET HexedNET;
var private HxNTClient Client;

function PreBeginPlay()
{
    Super.PreBeginPlay();
    foreach Weapon.DynamicActors(class'MutHexedNET', HexedNET) break;
    class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client);
    if (bAllowMultiHit != class'ZoomSuperShockBeamFire'.default.bAllowMultiHit)
    {
        ClearConfig();
        default.bAllowMultiHit = class'ZoomSuperShockBeamFire'.default.bAllowMultiHit;
        bAllowMultiHit = default.bAllowMultiHit;
    }
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

function TracePart(Vector Start, Vector End, Vector X, Rotator Dir, Pawn Ignored)
{
    if (Level.NetMode == NM_Client || !IsEnhancedNetcodeEnabled())
    {
        Super.TracePart(Start, End, X, Dir, Ignored);
        return;
    }
    class'HxNTWeapon'.static.SSRTrace(
        HexedNET,
        Self,
        Start,
        End,
        X,
        Dir,
        Ignored,
        Client.AveragePing,
        FirstGo,
        bBelievesHit,
        BelievedHitActor);
}

function DoClientTrace(Vector Start, Rotator Dir)
{
    class'HxNTWeapon'.static.SSRTraceClient(
        Self, Start, Start + vector(Dir) * TraceRange, Dir, Instigator);
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

function bool AllowMultiHit()
{
    if (Level.NetMode == NM_Client)
    {
        return default.bServerAllowMultiHit;
    }
    return bAllowMultiHit;
}
