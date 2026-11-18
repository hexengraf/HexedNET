class HxNet_FlakChunk extends FlakChunk;

var HxNTClient Client;
var int UID;
var bool bShouldRemove;

var private HxNTWeaponInfo WeaponInfo;
var private Vector InterpolationOffset;
var private float InterpolationPeriod;
var private bool bInterpolate;
var private int TickCount;

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
    local FlakChunk Predicted;

    WeaponInfo = Client.GetWeaponInfo(class'FlakCannon');
    Predicted = FlakChunk(WeaponInfo.MatchPrediction(Self, UID));
    if (Predicted != None)
    {
        InterpolatePredicted(Predicted);
        Predicted.Destroy();
    }
}

simulated function InterpolatePredicted(FlakChunk Predicted)
{
    if (Predicted != None)
    {
        if (Trail != None)
        {
            Trail.mRegen = false;
            Trail.SetPhysics(PHYS_None);
        }
        if (Predicted.Trail != None)
        {
            Trail = Predicted.Trail;
            Trail.SetOwner(Self);
            Predicted.Trail = None;
        }
        bInterpolate = true;
        InterpolationOffset = Location - Predicted.Location;
        DoSetLocation(Predicted.Location);
        SetRotation(Predicted.Rotation);
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

defaultproperties
{
    InterpolationPeriod=0.15
}
