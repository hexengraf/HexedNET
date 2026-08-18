class HxNet_SuperShockBeamFire extends SuperShockBeamFire
    DependsOn(HxNTWeapon);

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
    else
    {
        StaticTracePart(
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

static function StaticTracePart(MutHexedNET HexedNET,
                                SuperShockBeamFire WF,
                                Vector Start,
                                Vector End,
                                Vector X,
                                Rotator Dir,
                                Pawn Ignored,
                                float AveragePing,
                                out byte FirstGo,
                                Actor Injured)
{
    local Actor Other;
    local Vector HitLocation;
    local vector PastHitLocation;
    local Vector HitNormal;

    if (HexedNET != None)
    {
        HexedNET.TimeTravel(AveragePing);
        if (FirstGo == 1)
        {
            Other = HexedNET.CompensatedTrace2(
                AveragePing,
                WF.Weapon,
                HitLocation,
                HitNormal,
                End,
                Start,
                Injured,
                PastHitLocation);
            FirstGo = 0;
        }
        else
        {
            Other = HexedNET.CompensatedTrace(
                WF.Weapon, HitLocation, HitNormal, End, Start, PastHitLocation);
        }
        HexedNET.UnTimeTravel();
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
            if (Other.Level.NetMode != NM_Client)
            {
                Other.TakeDamage(
                    WF.DamageMax, WF.Instigator, HitLocation, WF.Momentum * X, WF.DamageType);
            }
            HitNormal = Vect(0, 0, 0);
            if (Pawn(Other) != None && HitLocation != Start && WF.AllowMultiHit())
            {
                // TODO: multi-hit in past or present?
                StaticTracePart(
                    HexedNET,
                    WF,
                    PastHitLocation,
                    End,
                    X,
                    Dir,
                    Pawn(Other),
                    AveragePing,
                    FirstGo,
                    Injured);
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
