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
        SearchDummyProjectile();
    }
}

simulated function SearchDummyProjectile()
{
    local array<Projectile> Dummies;
    local float Distance;
    local int i;

    Dummies = Client.GetDummies(class'LinkGun');
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
        InterpolateDummy(LinkProjectile(Dummies[i]));
        Client.DestroyDummy(class'LinkGun', i);
    }
}

simulated function InterpolateDummy(LinkProjectile Dummy)
{
    if (Dummy != None)
    {
        if (Trail != None)
        {
            Trail.Destroy();
        }
        if (Dummy.Trail != None)
        {
            Trail = Dummy.Trail;
            Trail.SetOwner(Self);
            Dummy.Trail = None;
        }
        bInterpolate = true;
        InterpolationOffset = Location - Dummy.Location;
        DoSetLocation(Dummy.Location);
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
