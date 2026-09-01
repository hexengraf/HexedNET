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
    local Vector Start;
    local Rotator Aim;

    Start = W.Instigator.Location + W.Instigator.EyePosition();
    Aim = W.FireMode[Mode].AdjustAim(Start, W.FireMode[Mode].AimError);
    if (bSpread)
    {
        Aim = Rotator(Vector(Aim) + VRand() * FRand() * W.FireMode[Mode].Spread);
    }
    BAS.X = Start.X;
    BAS.Y = Start.Y;
    BAS.Z = Start.Z;
    BAS.Yaw = Aim.Yaw;
    BAS.Pitch = Aim.Pitch;
    return BAS;
}

static final function DecodeBAS(HxBAS BAS, out Vector Start, out Rotator Dir)
{
    Start.X = BAS.X;
    Start.Y = BAS.Y;
    Start.Z = BAS.Z;
    Dir.Yaw = BAS.Yaw;
    Dir.Pitch = BAS.Pitch;
}

static function InstantFireTrace(MutHexedNET HexedNET,
                                 InstantFire WF,
                                 Vector Start,
                                 Rotator Dir,
                                 float AveragePing)
{
    local Vector X;
    local Vector End;
    local Vector HitLocation;
    local Vector HitNormal;
    local Vector RefNormal;
    local Actor Hit;
    local int Damage;
    local bool bRewind;
    local bool bDoReflect;
    local int ReflectNum;

    WF.MaxRange();
    ReflectNum = 0;
    bRewind = HexedNET != None;
    while (true)
    {
        bDoReflect = false;
        X = Vector(Dir);
        End = Start + WF.TraceRange * X;
        if (bRewind)
        {
            HexedNET.TimeTravel(AveragePing);
            Hit = HexedNET.CompensatedTrace(WF.Weapon, HitLocation, HitNormal, End, Start);
            HexedNET.UnTimeTravel();
            bRewind = false;
        }
        else
        {
            Hit = WF.Weapon.Trace(HitLocation, HitNormal, End, Start, true);
        }
        // TODO: is it safe to call UpdateHit in NM_Clients?
        if (Hit != None && (Hit != WF.Instigator || ReflectNum > 0))
        {
            // TODO: shield gun in the past
            if (WF.bReflective && Hit.IsA('xPawn')
                && xPawn(Hit).CheckReflect(HitLocation, RefNormal, WF.DamageMin * 0.25))
            {
                bDoReflect = true;
                HitNormal = Vect(0, 0, 0);
            }
            else if (!Hit.bWorldGeometry)
            {
                if (Hit.IsA('Vehicle')
                    || (!Hit.IsA('Pawn') && !Hit.IsA('HitScanBlockingVolume')))
                {
                    WeaponAttachment(WF.Weapon.ThirdPersonActor).UpdateHit(
                        Hit, HitLocation, HitNormal);
                }
                if (WF.Level.NetMode != NM_Client)
                {
                    Damage = WF.DamageMin;
                    if (WF.DamageMin != WF.DamageMax && FRand() > 0.5)
                    {
                        Damage += Rand(1 + WF.DamageMax - WF.DamageMin);
                    }
                    Damage = Damage * WF.DamageAtten;
                    Hit.TakeDamage(
                        Damage, WF.Instigator, HitLocation, WF.Momentum * X, WF.DamageType);
                }
                HitNormal = Vect(0, 0, 0);
            }
            else if (WeaponAttachment(WF.Weapon.ThirdPersonActor) != None)
            {
                WeaponAttachment(WF.Weapon.ThirdPersonActor).UpdateHit(Hit, HitLocation, HitNormal);
            }
        }
        else
        {
            HitLocation = End;
            HitNormal = Vect(0, 0, 0);
            WeaponAttachment(WF.Weapon.ThirdPersonActor).UpdateHit(Hit, HitLocation, HitNormal);
        }
        WF.SpawnBeamEffect(Start, Dir, HitLocation, HitNormal, ReflectNum);
        if (WF.Level.NetMode != NM_Client && bDoReflect && ++ReflectNum < 4)
        {
            Start = HitLocation;
            Dir = Rotator(RefNormal);
        }
        else
        {
            break;
        }
    }
}

defaultproperties
{
}
