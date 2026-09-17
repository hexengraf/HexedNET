class HxNet_SniperFire extends SniperFire
    DependsOn(HxNTWeapon);

var float ServerDelay;
var private MutHexedNET HexedNET;
var private HxNTClient Client;
var private Vector BASStart;
var private Rotator BASAim;
var private bool bBoostedAimSynchronization;

function PreBeginPlay()
{
    Super.PreBeginPlay();
    class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client);
}

function bool WantsPingCompensation()
{
    return class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        && Client.WantsPingCompensation();
}

function ApplyBAS(HxNTWeapon.HxBAS BAS)
{
    if (class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client))
    {
        class'HxNTWeapon'.static.DecodeBAS(BAS, BASStart, BASAim);
        bBoostedAimSynchronization = Client.IsAcceptableBAS(Weapon, BASStart, BASAim);
    }
}

function PlayFiring()
{
    Super.PlayFiring();
    if (Level.NetMode == NM_Client && WantsPingCompensation() && Instigator.IsLocallyControlled())
    {
        DoFireEffect();
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

function DoTrace(Vector Start, Rotator Dir)
{
    local Vector HitLocation;
    local Vector HitNormal;
    local Vector RefNormal;
    local Vector End;
    local Vector X;
    local Vector ArcStart;
    local Vector MainArcHit;
    local Actor Hit;
    local Actor MainArcHitTarget;
    local Pawn HeadShotPawn;
    local xEmitter HitEmitter;
    local class<Actor> TmpHitEmitClass;
    local float TmpTraceRange;
    local bool bDoReflect;
    local bool bRewind;
    local int Damage;
    local int ReflectNum;
    local int ArcsRemaining;

    if (!WantsPingCompensation())
    {
        Super.DoTrace(Start, Dir);
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
    TmpTraceRange = TraceRange;
    ReflectNum = 0;
    TmpHitEmitClass = HitEmitterClass;
    bRewind = HexedNET != None;
    while (true)
    {
        bDoReflect = false;
        X = Vector(Dir);
        End = Start + TmpTraceRange * X;
        if (bRewind)
        {
            HexedNET.Rewind(Client.GetCompensationTime() + ServerDelay);
            Hit = HexedNET.RewoundTrace(Weapon, HitLocation, HitNormal, End, Start);
            HexedNET.UndoRewind();
            TmpHitEmitClass = class'HxNet_NewLightningBolt';
            bRewind = false;
        }
        else
        {
            Hit = Weapon.Trace(HitLocation, HitNormal, End, Start, true);
        }
        if (Hit != None && (Hit != Instigator || ReflectNum > 0))
        {
            // TODO: shield gun in the past
            if (bReflective && Hit.IsA('xPawn')
                && xPawn(Hit).CheckReflect(HitLocation, RefNormal, DamageMin * 0.25))
            {
                bDoReflect = true;
            }
            else if (Hit != MainArcHitTarget)
            {
                if (Hit.bWorldGeometry)
                {
                    HitLocation = HitLocation + 2.0 * HitNormal;
                }
                else if (Level.NetMode != NM_Client)
                {
                    Damage = (DamageMin + Rand(DamageMax - DamageMin)) * DamageAtten;
                    if (Vehicle(Hit) != None)
                    {
                        HeadShotPawn = Vehicle(Hit).CheckForHeadShot(HitLocation, X, 1.0);
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
                    else if (Pawn(Hit) != None && ArcsRemaining == NumArcs
                        && Pawn(Hit).IsHeadShot(HitLocation, X, 1.0))
                    {
                        Hit.TakeDamage(
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
                        Hit.TakeDamage(Damage, Instigator, HitLocation, Momentum * X, DamageType);
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
            break;
        }
        HitEmitter = xEmitter(Weapon.Spawn(TmpHitEmitClass,,, ArcStart, Rotator(HitNormal)));
        if (HitEmitter != None)
        {
            HitEmitter.mSpawnVecA = HitLocation;
        }
        if (HitScanBlockingVolume(Hit) != None || Level.NetMode == NM_Client)
        {
            break;
        }
        if (ArcsRemaining == NumArcs)
        {
            MainArcHit = HitLocation + (HitNormal * 2.0);
            if (Hit != None && !Hit.bWorldGeometry)
            {
                MainArcHitTarget = Hit;
            }
        }
        if (bDoReflect && ++ReflectNum < 4)
        {
            Start = HitLocation;
            Dir = Rotator(X - 2.0 * RefNormal * (X dot RefNormal));
            TmpHitEmitClass = HitEmitterClass;
        }
        else if (ArcsRemaining > 0)
        {
            ArcsRemaining--;
            Start = MainArcHit;
            Dir = Rotator(VRand());
            TmpHitEmitClass = SecHitEmitterClass;
            TmpTraceRange = SecTraceDist;
            ArcStart = MainArcHit;
        }
        else
        {
            break;
        }
    }
}

function Vector GetArcStart(Vector EffectOffset)
{
    local Vector X;
    local Vector Y;
    local Vector Z;

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

defaultproperties
{
}
