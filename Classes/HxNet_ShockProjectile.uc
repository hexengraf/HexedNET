class HxNet_ShockProjectile extends ShockProjectile;

var HxNTClient Client;
var private HxNTProjectileTracker Tracker;
var private Vector InterpolationOffset;
var private float InterpolationPeriod;
var private bool bInterpolate;
var private int TickCount;

replication
{
    unreliable if (bDemoRecording)
        DoMove, DoSetLocation;

    reliable if (Role == ROLE_Authority && bNetInitial)
        Client;
}

simulated function PostNetBeginPlay()
{
    Super.PostNetBeginPlay();
    if (Level.NetMode == NM_Client && Client != None && Client.WantsPingCompensation())
    {
        SearchPredictedProjectile();
    }
}

simulated function SearchPredictedProjectile()
{
    local HxNTWeaponInfo WeaponInfo;
    local ShockProjectile Core;

    WeaponInfo = Client.GetWeaponInfo(class'ShockRifle');
    Core = ShockProjectile(WeaponInfo.MatchProjectile(Location));
    if (Core != None)
    {
        InterpolatePredicted(Core);
        Core.Destroy();
    }
}

simulated function InterpolatePredicted(ShockProjectile Predicted)
{
    if (Predicted != None)
    {
        if (Predicted.ShockBallEffect != None)
        {
            ShockBallEffect.Destroy();
            ShockBallEffect = Predicted.ShockBallEffect;
            ShockBallEffect.SetBase(None);
            ShockBallEffect.SetOwner(Self);
            ShockBallEffect.SetLocation(Location);
            ShockBallEffect.SetBase(Self);
            Predicted.ShockBallEffect = None;
        }
        if (Predicted.TimerRate > 0)
        {
            SetTimer(Predicted.TimerRate - Predicted.TimerCounter, false);
        }
        else
        {
            SetCollisionSize(Predicted.CollisionRadius, Predicted.CollisionHeight);
        }
        bInterpolate = true;
        InterpolationOffset = Location - Predicted.Location;
        DoSetLocation(Predicted.Location);
    }
}

simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    if (TickCount < 2)
    {
        ++TickCount;
    }
    if (bInterpolate)
    {
        DeltaTime = FMin(DeltaTime, InterpolationPeriod);
        if (DeltaTime > 0)
        {
            DoMove(InterpolationOffset * DeltaTime / default.InterpolationPeriod);
            InterpolationPeriod -= DeltaTime;
        }
        bInterpolate = InterpolationPeriod > 0;
    }
}

simulated function DoMove(Vector Offset)
{
    Move(Offset);
}

simulated function DoSetLocation(Vector NewLocation)
{
    SetLocation(NewLocation);
}

simulated function Explode(Vector HitLocation, Vector HitNormal)
{
    local HxNet_ShockProjectileEffects Effects;

    if (Role == ROLE_Authority && TickCount < 2)
    {
        HurtRadius(Damage, DamageRadius, MyDamageType, MomentumTransfer, HitLocation);
        Effects = Spawn(class'HxNet_ShockProjectileEffects',,, Location, Rotation);
        Effects.HitLocation = HitLocation;
        Effects.HitNormal = HitNormal;
        SetCollisionSize(0.0, 0.0);
        Destroy();
    }
    else
    {
        Super.Explode(HitLocation, HitNormal);
        if (bInterpolate)
        {
            bCollideWorld = false;
            SetCollision(false, false);
        }
    }
}

simulated function ProcessTouch(Actor Other, Vector HitLocation)
{
    local HxNet_ShockProjectile P;
    local Vector X;
    local Vector RefNormal;
    local Vector RefDir;

    if (Role == ROLE_Authority && Other != Instigator && Other != Owner && Other.IsA('xPawn')
        && xPawn(Other).CheckReflect(HitLocation, RefNormal, Damage * 0.25))
    {
        X = Normal(Velocity);
        RefDir = X - 2.0 * RefNormal * (X dot RefNormal);
        RefDir = RefNormal;
        P = Spawn(Class, Other,, HitLocation + RefDir * 20, Rotator(RefDir));
        if (P != None)
        {
            P.SetTracker(Tracker);
            Tracker = None;
        }
        DestroyTrails();
        Destroy();
    }
    else
    {
        Super.ProcessTouch(Other, HitLocation);
    }
}

function Timer()
{
    Super.Timer();
    if (Tracker != None)
    {
        Tracker.StoreRoutePoint();
    }
}

simulated event Destroyed()
{
    if (Tracker != None)
    {
        Tracker.Destroy();
    }
    Super.Destroyed();
}

function SetTracker(HxNTProjectileTracker T)
{
    Tracker = T;
    Tracker.SetTracked(Self);
}

defaultproperties
{
    InterpolationPeriod=0.30
}
