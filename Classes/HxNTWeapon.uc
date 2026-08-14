class HxNTWeapon extends Weapon
    abstract;

struct HxBAS
{
    var float X;
    var float Y;
    var float Z;
    var int Yaw;
    var int Pitch;
};

static function ForceBaseClassConfig(Weapon W, class<Weapon> BaseClass)
{
    W.default.ExchangeFireModes = BaseClass.default.ExchangeFireModes;
    W.ExchangeFireModes = W.default.ExchangeFireModes;
    W.default.Priority = BaseClass.default.Priority;
    W.Priority = W.default.Priority;
    W.default.CustomCrosshair = BaseClass.default.CustomCrosshair;
    W.CustomCrosshair = W.default.CustomCrosshair;
    W.default.CustomCrosshairColor = BaseClass.default.CustomCrosshairColor;
    W.CustomCrosshairColor = W.default.CustomCrosshairColor;
    W.default.CustomCrosshairScale = BaseClass.default.CustomCrosshairScale;
    W.CustomCrosshairScale = W.default.CustomCrosshairScale;
    W.default.CustomCrosshairTextureName = BaseClass.default.CustomCrosshairTextureName;
    W.CustomCrosshairTextureName = W.default.CustomCrosshairTextureName;
}

static function bool ValidateClient(LevelInfo Level,
                                    MutHexedNET HexedNET,
                                    Pawn Instigator,
                                    out HxNTClient Client)
{
    if (Client != None)
    {
        return true;
    }
    if (Level.NetMode == NM_Client)
    {
        foreach Level.DynamicActors(class'HxNTClient', Client) break;
    }
    else if (HexedNET != None && Instigator != None)
    {
        Client = HxNTClient(HexedNET.GetClientReplicationInfo(Instigator.Controller));
    }
    return Client != None;
}

static final function CheckStopFire(Weapon W, float StopFireTime, float AltStopFireTime)
{
    if (StopFireTime > 0 && W.Level.TimeSeconds >= StopFireTime
        && W.Instigator.Controller.bFire > 0 && W.FireMode[0].bIsFiring)
    {
        W.ClientStopFire(0);
    }
    if (AltStopFireTime > 0 && W.Level.TimeSeconds >= AltStopFireTime
        && W.Instigator.Controller.bAltFire > 0 && W.FireMode[1].bIsFiring)
    {
        W.ClientStopFire(1);
    }
}

static final function HxBAS EncodeBAS(vector Start, rotator Dir)
{
    local HxBAS BAS;

    BAS.X = Start.X;
    BAS.Y = Start.Y;
    BAS.Z = Start.Z;
    BAS.Yaw = Dir.Yaw;
    BAS.Pitch = Dir.Pitch;
    return BAS;
}

static final function DecodeBAS(HxBAS BAS, out vector Start, out rotator Dir)
{
    Start.X = BAS.X;
    Start.Y = BAS.Y;
    Start.Z = BAS.Z;
    Dir.Yaw = BAS.Yaw;
    Dir.Pitch = BAS.Pitch;
}

static function InstantFireTrace(MutHexedNET HexedNET,
                                 InstantFire WF,
                                 vector Start,
                                 rotator Dir,
                                 float AveragePing)
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

    WF.MaxRange();
    ReflectNum = 0;
    HexedNET.TimeTravel(AveragePing);
    while (true)
    {
        bDoReflect = false;
        X = vector(Dir);
        End = Start + WF.TraceRange * X;
        Other = HexedNET.CompensatedTrace(
            AveragePing, WF.Weapon, PresentHitLocation, HitLocation, HitNormal, End, Start);
        if (Other != None && (Other != WF.Instigator || ReflectNum > 0))
        {
            if (WF.bReflective && Other.IsA('xPawn')
                && xPawn(Other).CheckReflect(PresentHitLocation, RefNormal, WF.DamageMin * 0.25))
            {
                bDoReflect = true;
                HitNormal = Vect(0,0,0);
            }
            else if (!Other.bWorldGeometry)
            {
                Damage = WF.DamageMin;
                if (WF.DamageMin != WF.DamageMax && FRand() > 0.5)
                {
                    Damage += Rand(1 + WF.DamageMax - WF.DamageMin);
                }
                Damage = Damage * WF.DamageAtten;
                if (Other.IsA('Vehicle')
                    || (!Other.IsA('Pawn') && !Other.IsA('HitScanBlockingVolume')))
                {
                    WeaponAttachment(WF.Weapon.ThirdPersonActor).UpdateHit(
                        Other, PresentHitLocation, HitNormal);
                }
                Other.TakeDamage(
                    Damage, WF.Instigator, PresentHitLocation, WF.Momentum * X, WF.DamageType);
                HitNormal = Vect(0,0,0);
            }
            else if (WeaponAttachment(WF.Weapon.ThirdPersonActor) != None)
            {
                WeaponAttachment(WF.Weapon.ThirdPersonActor).UpdateHit(
                    Other, PresentHitLocation, HitNormal);
            }
        }
        else
        {
            HitLocation = End;
            HitNormal = Vect(0,0,0);
            WeaponAttachment(WF.Weapon.ThirdPersonActor).UpdateHit(
                Other, PresentHitLocation, HitNormal);
        }
        WF.SpawnBeamEffect(Start, Dir, HitLocation, HitNormal, ReflectNum);
        if (bDoReflect && ++ReflectNum < 4)
        {
            Start = HitLocation;
            Dir = rotator(RefNormal);
        }
        else
        {
            break;
        }
    }
    HexedNET.UnTimeTravel();
}

defaultproperties
{
}
