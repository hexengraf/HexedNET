class NewNet_ZoomSuperShockBeamFire extends ZoomSuperShockBeamFire;

var bool bServerAllowMultiHit;

var bool bUseReplicatedInfo;
var rotator SavedRot;
var vector SavedVec;

var bool bBelievesHit;
var Actor BelievedHitActor;
var byte FirstGo;

var private MutHexedNET HexedNET;
var private HxNTClient Client;
var private bool bStopFire;
var private int StopFireMode;

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
    if (Level.NetMode == NM_Client && IsEnhancedNetcodeEnabled()
        && Instigator.IsLocallyControlled())
    {
        DoFireEffect();
        if (bStopFire)
        {
            bStopFire = false;
            Weapon.ClientStopFire(StopFireMode);
        }
    }
}

function EnqueueStopFire(int Mode)
{
    StopFireMode = Mode;
    bStopFire = true;
}

function DoFireEffect()
{
    if (!bUseReplicatedInfo || !IsEnhancedNetcodeEnabled())
    {
        Super.DoFireEffect();
    }
    else
    {
        Instigator.MakeNoise(1.0);
        bUseReplicatedInfo = false;
        DoTrace(SavedVec, SavedRot);
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
            if (Instigator.PlayerReplicationInfo.Team != None
                && Instigator.PlayerReplicationInfo.Team.TeamIndex == 1)
            {
                Beam = Weapon.Spawn(class'NewNet_BlueSuperShockBeam', Weapon.Owner,, Start, Dir);
            }
            else
            {
                Beam = Weapon.Spawn(class'NewNet_SuperShockBeamEffect', Weapon.Owner,, Start, Dir);
            }
            if (ReflectNum != 0)
            {
                // prevents client side repositioning of beam start
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
    if (Level.NetMode == NM_Client || !IsEnhancedNetcodeEnabled())
    {
        Super.TracePart(Start, End, X, Dir, Ignored);
    }
    else
    {
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
}

function bool AllowMultiHit()
{
    if (Level.NetMode == NM_Client)
    {
        return default.bServerAllowMultiHit;
    }
    return bAllowMultiHit;
}
