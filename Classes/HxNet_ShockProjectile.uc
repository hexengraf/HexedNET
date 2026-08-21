class HxNet_ShockProjectile extends ShockProjectile;

const INTERPOLATION_PERIOD = 0.30;

var private MutHexedNET MutatorOwner;
var private bool bInterpolateDummy;
var private vector DummyOffset;
var private float ElapsedInterpolationTime;
var private bool bRewinded;
var private vector OriginalLocation;

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
            if (Client.IsEnhancedNetcodeEnabled()
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

function Register(MutHexedNET HexedNET)
{
    MutatorOwner = HexedNET;
}

function RewindLocation(float DeltaTime)
{
    if (!bRewinded)
    {
        OriginalLocation = Location;
        bRewinded = true;
    }
    // TODO: What about projectiles with trajectory changed by shield gun's reflection?
    SetLocation(OriginalLocation - Extrapolate(DeltaTime));
}

function RestoreLocation()
{
    if (bRewinded)
    {
        SetLocation(OriginalLocation);
        bRewinded = false;
    }
}

simulated event Destroyed()
{
    if (MutatorOwner != None)
    {
        MutatorOwner.RemoveShockProjectile(Self);
    }
    Super.Destroyed();
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

simulated function Explode(vector HitLocation, vector HitNormal)
{
    Super.Explode(HitLocation, HitNormal);
    if (bInterpolateDummy)
    {
        bCollideWorld = false;
        SetCollision(false, false);
    }
}

simulated final function vector Extrapolate(float DeltaTime)
{
    return Velocity * DeltaTime;
}

defaultproperties
{
}
