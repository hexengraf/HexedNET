class HxNet_FlakShell extends FlakShell;

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
    local FlakShell Predicted;

    WeaponInfo = Client.GetWeaponInfo(class'FlakCannon');
    Predicted = FlakShell(WeaponInfo.MatchPrediction(Self, UID));
    if (Predicted != None)
    {
        InterpolatePredicted(Predicted);
        Predicted.Destroy();
    }
}

simulated function InterpolatePredicted(FlakShell Predicted)
{
    if (Predicted != None)
    {
        if (Trail != None)
        {
            Trail.mRegen = false;
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

simulated function SpawnEffects(Vector HitLocation, Vector HitNormal)
{
    local HxNet_FlakShellEffects Effects;

    if (Role == ROLE_Authority && TickCount < 2)
    {
        Effects = Spawn(class'HxNet_FlakShellEffects',,, Location, Rotation);
        Effects.HitLocation = HitLocation;
        Effects.HitNormal = HitNormal;
    }
    else
    {
        Super.SpawnEffects(HitLocation, HitNormal);
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
    InterpolationPeriod=0.30
}
