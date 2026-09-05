class HxNet_BioGlob extends BioGlob;

const INTERPOLATION_PERIOD = 0.10;

var private Vector DummyOffset;
var private float ElapsedInterpolationTime;
var private bool bInterpolateDummy;

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

    Dummies = Client.GetDummies(class'BioRifle');
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
        InterpolateDummy(BioGlob(Dummies[i]));
        Client.DestroyDummyProjectile(class'BioRifle', i);
    }
}

// TODO: is there a way to interpolate flying globs without risking to bury them inside walls?
simulated function InterpolateDummy(BioGlob Dummy)
{
    local name Animation;
    local float Frame;
    local float Rate;

    if (Dummy != None && Dummy.IsInState('OnGround') && IsInState('OnGround'))
    {
        if (Dummy.IsAnimating())
        {
            Dummy.GetAnimParams(0, Animation, Frame, Rate);
            PlayAnim(Animation, Rate);
            SetAnimFrame(Frame);
        }
        bInterpolateDummy = true;
        DummyOffset = Location - Dummy.Location;
        DoSetLocation(Dummy.Location);
    }
}

simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    if (bInterpolateDummy)
    {
        DeltaTime = FMin(DeltaTime, INTERPOLATION_PERIOD - ElapsedInterpolationTime);
        bInterpolateDummy = DeltaTime > 0;
        if (bInterpolateDummy)
        {
            DoMove(DummyOffset * DeltaTime / INTERPOLATION_PERIOD);
            ElapsedInterpolationTime += DeltaTime;
            bInterpolateDummy = ElapsedInterpolationTime < INTERPOLATION_PERIOD;
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

defaultproperties
{
}
