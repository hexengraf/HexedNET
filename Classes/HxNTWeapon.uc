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

static final function CheckStopFire(Weapon W, out int StopFireTime, out int AltStopFireTime)
{
    if (StopFireTime > 0)
    {
        --StopFireTime;
        if (StopFireTime == 0 && W.Instigator.Controller.bFire > 0 && W.FireMode[0].bIsFiring)
        {
            W.ClientStopFire(0);
        }
    }
    if (AltStopFireTime > 0)
    {
        --AltStopFireTime;
        if (AltStopFireTime == 0 && W.Instigator.Controller.bAltFire > 0 && W.FireMode[1].bIsFiring)
        {
            W.ClientStopFire(1);
        }
    }
}

static final function HxBAS EncodeBAS(Weapon W, int Mode, optional bool bSpread)
{
    local HxBAS BAS;
    local vector Start;
    local rotator Aim;

    Start = W.Instigator.Location + W.Instigator.EyePosition();
    Aim = W.FireMode[Mode].AdjustAim(Start, W.FireMode[Mode].AimError);
    if (bSpread)
    {
        Aim = rotator(vector(Aim) + VRand() * FRand() * W.FireMode[Mode].Spread);
    }
    BAS.X = Start.X;
    BAS.Y = Start.Y;
    BAS.Z = Start.Z;
    BAS.Yaw = Aim.Yaw;
    BAS.Pitch = Aim.Pitch;
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
    local vector PastHitLocation;
    local vector HitNormal;
    local vector RefNormal;
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
            WF.Weapon, HitLocation, HitNormal, End, Start, PastHitLocation);
        if (Other != None && (Other != WF.Instigator || ReflectNum > 0))
        {
            if (WF.bReflective && Other.IsA('xPawn')
                && xPawn(Other).CheckReflect(HitLocation, RefNormal, WF.DamageMin * 0.25))
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
                        Other, HitLocation, HitNormal);
                }
                Other.TakeDamage(
                    Damage, WF.Instigator, HitLocation, WF.Momentum * X, WF.DamageType);
                HitNormal = Vect(0,0,0);
            }
            else if (WeaponAttachment(WF.Weapon.ThirdPersonActor) != None)
            {
                WeaponAttachment(WF.Weapon.ThirdPersonActor).UpdateHit(
                    Other, HitLocation, HitNormal);
            }
        }
        else
        {
            HitLocation = End;
            HitNormal = Vect(0,0,0);
            WeaponAttachment(WF.Weapon.ThirdPersonActor).UpdateHit(
                Other, HitLocation, HitNormal);
        }
        WF.SpawnBeamEffect(Start, Dir, HitLocation, HitNormal, ReflectNum);
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
    HexedNET.UnTimeTravel();
}

static final function Vector ExtrapolateFalling(PhysicsVolume Volume,
                                                Vector Start,
                                                float DeltaTime,
                                                out Vector Velocity)
{
    local Vector PreviousVelocity;
    local Vector Delta;

    PreviousVelocity = Velocity;
    Delta = AdvanceFalling(Volume, Velocity, DeltaTime);
    Velocity = AdjustFallingVelocity(Volume, PreviousVelocity, Delta, DeltaTime);
    return Start + Delta;
}

static final function Vector AdvanceFalling(PhysicsVolume Volume,
                                            out Vector Velocity,
                                            float DeltaTime)
{
    if (Volume.bWaterVolume)
    {
        Velocity *= 1.0 - Volume.FluidFriction * DeltaTime;
    }
    Velocity += Volume.Gravity * DeltaTime * 0.5;
    return (Velocity + Volume.ZoneVelocity) * DeltaTime;
}

static final function Vector AdjustFallingVelocity(PhysicsVolume Volume,
                                                   Vector PreviousVelocity,
                                                   Vector Delta,
                                                   float DeltaTime)
{
    local Vector Velocity;

    Velocity = Delta / DeltaTime - Volume.ZoneVelocity;
    if (Velocity.Z < PreviousVelocity.Z || PreviousVelocity.Z >= 0)
    {
        Velocity = 2 * Velocity - PreviousVelocity;
    }
    if (VSize(Velocity) > Volume.TerminalVelocity)
    {
        Velocity = Normal(Velocity) * Volume.TerminalVelocity;
    }
    return Velocity;
}

defaultproperties
{
}
