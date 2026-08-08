class NewNet_SuperShockBeamFire extends SuperShockBeamFire;

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
        else if (Instigator.IsLocallyControlled())
        {
           DoFireEffect();
        }
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
    if (!IsEnhancedNetcodeEnabled())
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

DefaultProperties
{
}
