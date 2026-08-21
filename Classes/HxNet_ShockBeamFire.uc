class HxNet_ShockBeamFire extends ShockBeamFire
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
    local vector X;
    local vector Y;
    local vector Z;

    class'HxNTWeapon'.static.DecodeBAS(BAS, BASStart, BASAim);
    if (HexedNET == None || HexedNET.IsReasonable(Weapon, BASStart))
    {
        if (PlayerController(Instigator.Controller) != None)
        {
            GetAxes(BASAim, X, Y, Z);
            BASStart += X * class'ShockProjFire'.Default.ProjSpawnOffset.X;
            if (!Weapon.WeaponCentered())
            {
                BASStart += Weapon.Hand * Y * class'ShockProjFire'.Default.ProjSpawnOffset.Y
                    + Z * class'ShockProjFire'.Default.ProjSpawnOffset.Z;
            }
        }
        bBoostedAimSynchronization = true;
    }
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

    if (!IsEnhancedNetcodeEnabled())
    {
        Super.SpawnBeamEffect(Start, Dir, HitLocation, HitNormal, ReflectNum);
    }
    else if (Weapon != None)
    {
        Beam = Weapon.Spawn(Class'HxNet_ShockBeamEffect', Weapon,, Start, Dir);
        if (ReflectNum != 0)
        {
            Beam.Instigator = None;
        }
        Beam.AimAt(HitLocation, HitNormal);
    }
}

function DoTrace(vector Start, rotator Dir)
{
    local WeaponAttachment Attachment;
    local Actor Other;
    local vector X;
    local vector End;
    local vector HitLocation;
    local vector PastHitLocation;
    local vector HitNormal;
    local vector RefNormal;
    local int Damage;
    local bool bDoReflect;
    local int ReflectNum;

    if (!IsEnhancedNetcodeEnabled())
    {
        Super.DoTrace(Start, Dir);
        return;
    }
    MaxRange();
    ReflectNum = 0;
    Attachment = WeaponAttachment(Weapon.ThirdPersonActor);
    while (true)
    {
        bDoReflect = false;
        X = vector(Dir);
        End = Start + TraceRange * X;
        if (HexedNET != None)
        {
            HexedNET.TimeTravel(Client.AveragePing + ServerDelay);
            Other = HexedNET.CompensatedTrace(
                Weapon, HitLocation, HitNormal, End, Start, PastHitLocation);
            if (Other != None && Other.IsA('ShockProjectile'))
            {
                HexedNET.UnTimeTravel();
            }
        }
        else
        {
            Other = Weapon.Trace(HitLocation, HitNormal, End, Start, true);
            PastHitLocation = HitLocation;
        }
        if (Other != None && (Other != Instigator || ReflectNum > 0))
        {
            if (bReflective && Other.IsA('xPawn')
                && xPawn(Other).CheckReflect(HitLocation, RefNormal, DamageMin * 0.25))
            {
                bDoReflect = true;
                HitNormal = Vect(0, 0, 0);
            }
            else if (!Other.bWorldGeometry)
            {
                Damage = DamageMin;
                if (DamageMin != DamageMax && (FRand() > 0.5))
                {
                    Damage += Rand(1 + DamageMax - DamageMin);
                }
                Damage = Damage * DamageAtten;
                if (Other.IsA('Vehicle')
                    || (!Other.IsA('Pawn') && !Other.IsA('HitScanBlockingVolume')))
                {
                    Attachment.UpdateHit(Other, HitLocation, HitNormal);
                }
                if (Level.NetMode != NM_Client)
                {
                    Other.TakeDamage(Damage, Instigator, HitLocation, Momentum * X, DamageType);
                }
                HitNormal = Vect(0, 0, 0);
            }
            else if (Attachment != None)
            {
                Attachment.UpdateHit(Other, HitLocation, HitNormal);
            }
        }
        else
        {
            HitLocation = End;
            HitNormal = Vect(0, 0, 0);
            Attachment.UpdateHit(Other, HitLocation, HitNormal);
        }
        SpawnBeamEffect(Start, Dir, HitLocation, HitNormal, ReflectNum);
        if (bDoReflect && ++ReflectNum < 4)
        {
            // TODO: reflections in past or present?
            Start = PastHitLocation;
            Dir = rotator(RefNormal);
        }
        else
        {
            break;
        }
    }
    if (HexedNET != None)
    {
        HexedNET.UnTimeTravel();
    }
}

DefaultProperties
{
}
