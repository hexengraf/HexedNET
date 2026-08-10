class NewNet_ShockBeamFire extends ShockBeamFire;

var bool bUseReplicatedInfo;
var rotator SavedRot;
var vector SavedVec;

var bool bBelievesHit;
var Actor BelievedHitActor;
var bool bFirstGo;

var private MutHexedNET HexedNET;
var private HxNTClient Client;
var private bool bStopFire;
var private int StopFireMode;

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
            Beam = Weapon.Spawn(Class'NewNet_ShockBeamEffect', Weapon.Owner,, Start, Dir);
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

    if (!IsEnhancedNetcodeEnabled())
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
        if (HexedNET != None)
        {
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
        }
        else
        {
            Other = Weapon.Trace(HitLocation, HitNormal, End, Start, true);
        }
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
                if (Level.NetMode != NM_Client)
                {
                    Other.TakeDamage(Damage, Instigator, PresentHitLocation, Momentum * X, DamageType);
                }
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

DefaultProperties
{
}
