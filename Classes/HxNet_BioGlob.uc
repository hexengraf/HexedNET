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
        SearchPredictedProjectile();
    }
}

simulated function SearchPredictedProjectile()
{
    local HxNTWeaponInfo WeaponInfo;
    local BioGlob Glob;

    WeaponInfo = Client.GetWeaponInfo(class'BioRifle');
    Glob = BioGlob(WeaponInfo.MatchProjectile(Location));
    if (Glob != None)
    {
        InterpolatePredicted(Glob);
        Glob.Destroy();
    }
}

// TODO: is there a way to interpolate flying globs without risking to bury them inside walls?
simulated function InterpolatePredicted(BioGlob Predicted)
{
    local name Animation;
    local float Frame;
    local float Rate;

    if (Predicted != None && Predicted.IsInState('OnGround') && IsInState('OnGround'))
    {
        if (Predicted.IsAnimating())
        {
            Predicted.GetAnimParams(0, Animation, Frame, Rate);
            PlayAnim(Animation, Rate);
            SetAnimFrame(Frame);
        }
        bInterpolate = true;
        InterpolationOffset = Location - Predicted.Location;
        DoSetLocation(Predicted.Location);
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
