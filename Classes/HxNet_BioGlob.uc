class HxNet_BioGlob extends BioGlob;

var HxNTClient Client;
var int UID;
var bool bShouldRemove;

var private HxNTWeaponInfo WeaponInfo;
var private Vector InterpolationOffset;
var private float InterpolationPeriod;
var private bool bInterpolate;

replication
{
    unreliable if (bDemoRecording)
        DoMove, DoSetLocation;

    reliable if (Role == ROLE_Authority && bNetInitial)
        Client, UID;
}

simulated event PostNetBeginPlay()
{
    Super.PostNetBeginPlay();
    if (Level.NetMode == NM_Client && Client != None && Client.WantsLagCompensation())
    {
        SearchPredictedProjectile();
    }
}

simulated event Destroyed()
{
    if (bShouldRemove && WeaponInfo != None)
    {
        WeaponInfo.RemoveAuthoritativeProjectile(Self);
        WeaponInfo = None;
    }
    Super.Destroyed();
}

simulated function SearchPredictedProjectile()
{
    local BioGlob Predicted;

    WeaponInfo = Client.GetWeaponInfo(class'BioRifle');
    Predicted = BioGlob(WeaponInfo.MatchPrediction(Self, UID));
    if (Predicted != None)
    {
        InterpolatePredicted(Predicted);
        Predicted.Destroy();
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
