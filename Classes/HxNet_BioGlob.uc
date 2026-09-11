class HxNet_BioGlob extends BioGlob;

var HxNTClient Client;
var private HxNTProjectileTracker Tracker;
var private Vector InterpolationOffset;
var private float InterpolationPeriod;
var private bool bInterpolate;

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
        SearchDummyProjectile();
    }
}

simulated function SearchDummyProjectile()
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
        Client.DestroyDummy(class'BioRifle', i);
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
        bInterpolate = true;
        InterpolationOffset = Location - Dummy.Location;
        DoSetLocation(Dummy.Location);
    }
}

simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
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

defaultproperties
{
    InterpolationPeriod=0.15
}
