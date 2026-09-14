class HxNet_LinkProjectile extends LinkProjectile;

var HxNTClient Client;
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
    local LinkProjectile Proj;

    WeaponInfo = Client.GetWeaponInfo(class'LinkGun');
    Proj = LinkProjectile(WeaponInfo.MatchProjectile(Location));
    if (Proj != None)
    {
        InterpolatePredicted(Proj);
        Proj.Destroy();
    }
}

simulated function InterpolatePredicted(LinkProjectile Predicted)
{
    if (Predicted != None)
    {
        if (Trail != None)
        {
            Trail.Destroy();
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

simulated function Explode(Vector HitLocation, Vector HitNormal)
{
    local HxNet_LinkProjectileEffects Effects;

    if (Role == ROLE_Authority && TickCount < 2)
    {
        Effects = Spawn(class'HxNet_LinkProjectileEffects',,, Location, Rotation);
        Effects.HitLocation = HitLocation;
        Effects.HitNormal = HitNormal;
        Effects.bYellow = Links > 0;
        Destroy();
    }
    else
    {
        Super.Explode(HitLocation, HitNormal);
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
