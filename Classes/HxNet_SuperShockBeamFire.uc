class HxNet_SuperShockBeamFire extends SuperShockBeamFire
    DependsOn(HxNTWeapon);

var float ServerDelay;
var private MutHexedNET HexedNET;
var private HxNTClient Client;
var private vector BASStart;
var private rotator BASAim;
var private bool bBoostedAimSynchronization;

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
    if (Level.NetMode == NM_Client && IsEnhancedNetcodeEnabled()
        && Instigator.IsLocallyControlled())
    {
        DoFireEffect();
    }
}

function ApplyBAS(HxNTWeapon.HxBAS BAS)
{
    class'HxNTWeapon'.static.DecodeBAS(BAS, BASStart, BASAim);
    bBoostedAimSynchronization = HexedNET == None || HexedNET.IsReasonable(Weapon, BASStart);
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
    ServerDelay = 0;
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
    if (!IsEnhancedNetcodeEnabled())
    {
        Super.TracePart(Start, End, X, Dir, Ignored);
    }
    else if (HexedNET != None)
    {
        HexedNET.TimeTravel(Client.AveragePing + ServerDelay);
        StaticTracePart(HexedNET, Self, Start, End, X, Dir, Ignored);
        HexedNET.UnTimeTravel();
    }
    else
    {
        StaticTracePart(HexedNET, Self, Start, End, X, Dir, Ignored);
    }
}

static function StaticTracePart(MutHexedNET HexedNET,
                                SuperShockBeamFire WF,
                                Vector Start,
                                Vector End,
                                Vector X,
                                Rotator Dir,
                                Pawn Ignored)
{
    local Actor Other;
    local Vector HitLocation;
    local vector PastHitLocation;
    local Vector HitNormal;

    if (HexedNET != None)
    {
        Other = HexedNET.CompensatedTrace(
            WF.Weapon, HitLocation, HitNormal, End, Start, PastHitLocation);
    }
    else
    {
        Other = Ignored.Trace(HitLocation, HitNormal, End, Start, true);
        PastHitLocation = HitLocation;
    }
    if (Other != None && Other != Ignored)
    {
        if (!Other.bWorldGeometry)
        {
            if (WF.Level.NetMode != NM_Client)
            {
                Other.TakeDamage(
                    WF.DamageMax, WF.Instigator, HitLocation, WF.Momentum * X, WF.DamageType);
            }
            HitNormal = Vect(0, 0, 0);
            if (Pawn(Other) != None && HitLocation != Start && WF.AllowMultiHit())
            {
                // TODO: multi-hit in past or present?
                StaticTracePart(HexedNET, WF, PastHitLocation, End, X, Dir, Pawn(Other));
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

DefaultProperties
{
}
