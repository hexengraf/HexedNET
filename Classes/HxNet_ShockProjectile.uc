class HxNet_ShockProjectile extends ShockProjectile;

const INTERPOLATION_PERIOD = 0.30;

var private bool bInterpolateDummy;
var private Vector DummyOffset;
var private float ElapsedInterpolationTime;
var private HxNTProjectileTracker Tracker;

replication
{
    unreliable if (bDemoRecording)
        DoMove, DoSetLocation;
}

simulated function PostNetBeginPlay()
{
    local PlayerController PC;
    local HxNTClient Client;

    Super.PostNetBeginPlay();
    if (Level.NetMode == NM_Client)
    {
        PC = Level.GetLocalPlayerController();
        foreach DynamicActors(class'HxNTClient', Client)
        {
            if (Client.WantsPingCompensation()
                && PC != None && PC.Pawn != None && PC.Pawn == Instigator)
            {
                SearchPredictedProjectile(Client);
            }
            break;
        }
    }
}

simulated function SearchPredictedProjectile(HxNTClient Client)
{
    local array<Projectile> Dummies;
    local float Distance;
    local int i;

    Dummies = Client.GetDummies(class'ShockRifle');
    if (Dummies.Length > 0)
    {
        Distance = VSize(Location - Dummies[0].Location);
        for (i = 1; i < Dummies.Length; ++i)
        {
            if (VSize(Location - Dummies[i].Location) > Distance)
            {
                break;
            }
        }
        --i;
        InterpolateDummy(ShockProjectile(Dummies[i]));
        Client.DestroyDummyProjectile(class'ShockRifle', i);
    }
}

simulated function InterpolateDummy(ShockProjectile Dummy)
{
    if (Dummy != None)
    {
        bInterpolateDummy = true;
        DummyOffset = Location - Dummy.Location;
        DoSetLocation(Dummy.Location);
        if (ShockBallEffect != None)
        {
            ShockBallEffect.Destroy();
            ShockBallEffect = Dummy.ShockBallEffect;
            ShockBallEffect.SetBase(None);
            ShockBallEffect.SetOwner(Self);
            ShockBallEffect.SetLocation(Location);
            ShockBallEffect.SetBase(Self);
            Dummy.ShockBallEffect = None;
        }
    }
}

simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    if (bInterpolateDummy)
    {
        DeltaTime = FMin(DeltaTime, INTERPOLATION_PERIOD - ElapsedInterpolationTime);
        if (DeltaTime > 0)
        {
            DoMove(DummyOffset * DeltaTime / INTERPOLATION_PERIOD);
            ElapsedInterpolationTime += DeltaTime;
            bInterpolateDummy = ElapsedInterpolationTime < INTERPOLATION_PERIOD;
        }
        else
        {
            bInterpolateDummy = false;
        }
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
    Super.Explode(HitLocation, HitNormal);
    if (bInterpolateDummy)
    {
        bCollideWorld = false;
        SetCollision(false, false);
    }
}

simulated function ProcessTouch(Actor Other, Vector HitLocation)
{
    local HxNet_ShockProjectile P;
    local Vector X;
    local Vector RefNormal;
    local Vector RefDir;

    if (Role == ROLE_Authority && Other != Instigator && Other != Owner
        && Other.IsA('xPawn') && xPawn(Other).CheckReflect(HitLocation, RefNormal, Damage * 0.25))
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
}
