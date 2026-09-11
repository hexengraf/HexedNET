class HxNet_FlakShell extends FlakShell;

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
    local float MinDistance;
    local float Distance;
    local float DummyIndex;
    local int i;

    Dummies = Client.GetDummies(class'FlakCannon');
    if (Dummies.Length > 0)
    {
        DummyIndex = -1;
        MinDistance = MaxInt;
        for (i = 0; i < Dummies.Length; ++i)
        {
            if (FlakShell(Dummies[i]) != None)
            {
                Distance = VSize(Location - Dummies[i].Location);
                if (Distance < MinDistance)
                {
                    MinDistance = Distance;
                    DummyIndex = i;
                }
                else
                {
                    break;
                }
            }
        }
        if (DummyIndex > -1)
        {
            InterpolateDummy(FlakShell(Dummies[DummyIndex]));
            Client.DestroyDummy(class'FlakCannon', DummyIndex);
        }
    }
}

simulated function InterpolateDummy(FlakShell Dummy)
{
    if (Dummy != None)
    {
        if (Trail != None)
        {
            Trail.mRegen = false;
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
    InterpolationPeriod=0.15
}
