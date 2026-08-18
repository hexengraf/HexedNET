class HxNet_SniperFire extends SniperFire;

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
}

function DoTrace(vector Start, Rotator Dir)
{
    local vector HitLocation;
    local vector HitNormal;
    local vector RefNormal;
    local vector PastHitLocation;
    local vector End;
    local vector X;
    local vector ArcStart;
    local vector MainArcHit;
    local Actor Other;
    local Actor MainArcHitTarget;
    local Pawn HeadShotPawn;
    local xEmitter HitEmitter;
    local class<Actor> TmpHitEmitClass;
    local float TmpTraceRange;
    local bool bDoReflect;
    local int Damage;
    local int ReflectNum;
    local int ArcsRemaining;

    if (!IsEnhancedNetcodeEnabled())
    {
        super.DoTrace(Start, Dir);
        return;
    }
    if (class'PlayerController'.Default.bSmallWeapons)
    {
        ArcStart = GetArcStart(Weapon.SmallEffectOffset);
    }
    else
    {
        ArcStart = GetArcStart(Weapon.EffectOffset);
    }
    ArcsRemaining = NumArcs;
    TmpHitEmitClass = class'HxNet_NewLightningBolt';
    TmpTraceRange = TraceRange;
    ReflectNum = 0;
    if (HexedNET != None)
    {
        HexedNET.TimeTravel(Client.AveragePing);
    }
    while (true)
    {
        bDoReflect = false;
        X = vector(Dir);
        End = Start + TmpTraceRange * X;
        if (HexedNET != None)
        {
            Other = HexedNET.CompensatedTrace(
                Weapon, HitLocation, HitNormal, End, Start, PastHitLocation);
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
            }
            else if (Other != MainArcHitTarget)
            {
                if (Other.bWorldGeometry)
                {
                    HitLocation = HitLocation + 2.0 * HitNormal;
                }
                else if (Level.NetMode != NM_Client)
                {
                    Damage = (DamageMin + Rand(DamageMax - DamageMin)) * DamageAtten;
                    if (Vehicle(Other) != None)
                    {
                        HeadShotPawn = Vehicle(Other).CheckForHeadShot(HitLocation, X, 1.0);
                    }
                    if (HeadShotPawn != None)
                    {
                        HeadShotPawn.TakeDamage(
                            Damage * HeadShotDamageMult,
                            Instigator,
                            HitLocation,
                            Momentum * X,
                            DamageTypeHeadShot);
                    }
                    else if (Pawn(Other) != None && ArcsRemaining == NumArcs
                        && Pawn(Other).IsHeadShot(HitLocation, X, 1.0))
                    {
                        Other.TakeDamage(
                            Damage * HeadShotDamageMult,
                            Instigator,
                            HitLocation,
                            Momentum * X,
                            DamageTypeHeadShot);
                    }
                    else
                    {
                        if (ArcsRemaining < NumArcs)
                        {
                            Damage *= SecDamageMult;
                        }
                        Other.TakeDamage(
                            Damage,
                            Instigator,
                            HitLocation,
                            Momentum * X,
                            DamageType);
                    }
                }
            }
        }
        else
        {
            HitLocation = End;
            HitNormal = Normal(Start - End);
        }
        if (Weapon == None)
        {
            HexedNET.UnTimeTravel();
            return;
        }
        HitEmitter = xEmitter(Weapon.Spawn(TmpHitEmitClass,,, ArcStart, Rotator(HitNormal)));
        if (HitEmitter != None)
        {
            HitEmitter.mSpawnVecA = HitLocation;
        }
        if (HitScanBlockingVolume(Other) != None)
        {
            HexedNET.UnTimeTravel();
            return;
        }
        if (ArcsRemaining == NumArcs)
        {
            // TODO: sub-arcs in past or present?
            MainArcHit = PastHitLocation + (HitNormal * 2.0);
            if (Other != None && !Other.bWorldGeometry)
            {
                MainArcHitTarget = Other;
            }
        }
        if (bDoReflect && ++ReflectNum < 4)
        {
            // TODO: reflections in past or present?
            Start = PastHitLocation;
            Dir = Rotator(X - 2.0 * RefNormal * (X dot RefNormal));
        }
        else if (ArcsRemaining > 0)
        {
            ArcsRemaining--;
            Start = MainArcHit;
            // TODO: this VRand is not synced between client and server!
            Dir = Rotator(VRand());
            TmpHitEmitClass = class'HxNet_ChildLightningBolt';
            TmpTraceRange = SecTraceDist;
            ArcStart = MainArcHit;
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

function vector GetArcStart(vector EffectOffset)
{
    local vector X;
    local vector Y;
    local vector Z;

    Weapon.GetViewAxes(X, Y, Z);
    if (Level.NetMode == NM_DedicatedServer)
    {
        return Instigator.Location
            + Instigator.BaseEyeHeight * vect(0,0,1)
            + EffectOffset.Z * Z
            + EffectOffset.Y * Y
            + EffectOffset.X * X;
    }
    if (Weapon.WeaponCentered() || SniperRifle(Weapon).zoomed)
    {
        return Instigator.Location + EffectOffset.Z * Z;
    }
    if (Weapon.Hand == 0)
    {
        if (!class'PlayerController'.Default.bSmallWeapons)
        {
            return Instigator.Location + EffectOffset.X * X - 0.5 * EffectOffset.Z * Z;
        }
        return Instigator.Location + EffectOffset.X * X;
    }
    return Instigator.Location
        + Instigator.CalcDrawOffset(Weapon)
        + EffectOffset.X * X
        + Weapon.Hand * EffectOffset.Y * Y
        + EffectOffset.Z * Z;
}

DefaultProperties
{
}
