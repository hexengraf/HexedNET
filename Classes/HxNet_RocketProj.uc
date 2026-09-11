class HxNet_RocketProj extends RocketProj;

var HxNTClient Client;
var int Index;
var private Vector InterpolationOffset;
var private float InterpolationPeriod;
var private bool bInterpolate;
var private int TickCount;

replication
{
    unreliable if (bDemoRecording)
        DoMove, DoSetLocation;

    reliable if (Role == ROLE_Authority && bNetInitial)
        Client, Index;
}

simulated function PostNetBeginPlay()
{
    local PlayerController PC;

    Super(Projectile).PostNetBeginPlay();
    if (Level.NetMode == NM_Client && Client != None && Client.WantsPingCompensation())
    {
        SearchDummyProjectile();
    }
    if (FlockIndex != 0)
    {
        SetTimer(0.1, true);
        if (Flock[1] == None)
        {
            PopulateFlock(Self);
        }
    }
    if (Level.NetMode != NM_DedicatedServer)
    {
        if (Level.bDropDetail || Level.DetailMode == DM_Low)
        {
            bDynamicLight = false;
            LightType = LT_None;
        }
        else
        {
            PC = Level.GetLocalPlayerController();
            if ((Instigator == None || PC != Instigator.Controller)
                && (PC == None || PC.ViewTarget == None
                    || VSize(PC.ViewTarget.Location - Location) > 3000))
            {
                bDynamicLight = false;
                LightType = LT_None;
            }
        }
    }
}

simulated function SearchDummyProjectile()
{
    local array<Projectile> Dummies;
    local float MinDistance;
    local float Distance;
    local int DummyIndex;
    local int i;

    Dummies = Client.GetDummies(class'RocketLauncher');
    if (Dummies.Length > 0)
    {
        DummyIndex = -1;
        MinDistance = MaxInt;
        for (i = 0; i < Dummies.Length; ++i)
        {
            if (HxNet_RocketProjDummy(Dummies[i]) != None
                && HxNet_RocketProjDummy(Dummies[i]).Index == Index)
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
            InterpolateDummy(RocketProj(Dummies[DummyIndex]));
            Client.DestroyDummy(class'RocketLauncher', DummyIndex);
        }
    }
}

simulated function InterpolateDummy(RocketProj Dummy)
{
    if (Dummy != None)
    {
        ApplyDummyEffects(Self, Dummy);
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
    local HxNet_RocketProjEffects Effects;

    if (Role == ROLE_Authority && TickCount < 2)
    {
        Effects = Spawn(class'HxNet_RocketProjEffects',,, Location, Rotation);
        Effects.HitLocation = HitLocation;
        Effects.HitNormal = HitNormal;
        BlowUp(HitLocation);
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

static function ApplyDummyEffects(RocketProj P, RocketProj Dummy)
{
    if (P.SmokeTrail != None)
    {
        P.SmokeTrail.mRegen = false;
    }
    if (Dummy.SmokeTrail != None)
    {
        P.SmokeTrail = Dummy.SmokeTrail;
        P.SmokeTrail.SetOwner(P);
        Dummy.SmokeTrail = None;
    }
    if (P.Corona != None)
    {
        P.Corona.Destroy();
    }
    if (Dummy.Corona != None)
    {
        P.Corona = Dummy.Corona;
        P.Corona.SetOwner(P);
        Dummy.Corona = None;
    }
}

static simulated function PopulateFlock(RocketProj P)
{
    local RocketProj R;
    local int i;

    foreach P.DynamicActors(class'RocketProj', R)
    {
        if (R.FlockIndex == P.FlockIndex && R.Class == P.Class)
        {
            P.Flock[i] = R;
            if (R.Flock[0] == None)
            {
                R.Flock[0] = P;
            }
            else if (R.Flock[0] != P)
            {
                R.Flock[1] = P;
            }
            ++i;
            if (i == 2)
            {
                break;
            }
        }
    }
}

static function RemoveFromFlock(RocketProj P)
{
    local int i;
    local int j;

    for (i = 0; i < ArrayCount(P.Flock); ++i)
    {
        if (P.Flock[i] != None)
        {
            for (j = 0; j < ArrayCount(P.Flock); ++j)
            {
                if (P.Flock[i].Flock[j] == P)
                {
                    P.Flock[i].Flock[j] = None;
                }
            }
        }
    }
}

defaultproperties
{
    InterpolationPeriod=0.30
}
