class HxNet_ZoomSuperShockBeamFire extends ZoomSuperShockBeamFire
    DependsOn(HxNTWeapon);

var bool bServerAllowMultiHit;

var private MutHexedNET HexedNET;
var private HxNTClient Client;
var private vector BASStart;
var private rotator BASAim;
var private Actor Injured;
var private bool bBoostedAimSynchronization;
var private byte EvaluateInjured;

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
    }
}

function ApplyBAS(HxNTWeapon.HxBAS BAS, optional Actor InjuredActor)
{
    class'HxNTWeapon'.static.DecodeBAS(BAS, BASStart, BASAim);
    bBoostedAimSynchronization = HexedNET == None || HexedNET.IsReasonable(Weapon, BASStart);
    Injured = InjuredActor;
    EvaluateInjured = 1;
}

function DoFireEffect()
{
    if (bBoostedAimSynchronization)
    {
        Instigator.MakeNoise(1.0);
        DoTrace(BASStart, BASAim);
        bBoostedAimSynchronization = false;
    }
    else
    {
        Super.DoFireEffect();
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
    if (Level.NetMode == NM_Client || !IsEnhancedNetcodeEnabled())
    {
        Super.TracePart(Start, End, X, Dir, Ignored);
    }
    else
    {
        class'HxNet_SuperShockBeamFire'.static.StaticTracePart(
            HexedNET,
            Self,
            Start,
            End,
            X,
            Dir,
            Ignored,
            Client.AveragePing,
            EvaluateInjured,
            Injured);
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
