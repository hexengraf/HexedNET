class HxNTWeapon extends Actor
    abstract;

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

static function SSRTrace(MutHexedNET HexedNET,
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
    local Vector HitNormal;
    local vector PresentHitLocation;

    if (HexedNET != None)
    {
        HexedNET.TimeTravel(AveragePing);
        if (FirstGo == 1)
        {
            Other = HexedNET.CompensatedTrace2(
                AveragePing,
                WF.Weapon,
                PresentHitLocation,
                HitLocation,
                HitNormal,
                End,
                Start,
                Injured);
            FirstGo = 0;
        }
        else
        {
            Other = HexedNET.CompensatedTrace(
                AveragePing, WF.Weapon, PresentHitLocation, HitLocation, HitNormal, End, Start);
        }
        HexedNET.UnTimeTravel();
    }
    else
    {
        Other = Ignored.Trace(HitLocation, HitNormal, End, Start, true);
    }
    if (Other != None && Other != Ignored)
    {
        if (!Other.bWorldGeometry)
        {
            if (Other.Level.NetMode != NM_Client)
            {
                Other.TakeDamage(
                    WF.DamageMax, WF.Instigator, PresentHitLocation, WF.Momentum * X, WF.DamageType);
            }
            HitNormal = vect(0,0,0);
            if (Pawn(Other) != None && HitLocation != Start && WF.AllowMultiHit())
            {
                SSRTrace(
                    HexedNET,
                    WF,
                    HitLocation,
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
        HitNormal = vect(0,0,0);
    }
    WF.SpawnBeamEffect(Start, Dir, HitLocation, HitNormal, 0);
}

defaultproperties
{
}
