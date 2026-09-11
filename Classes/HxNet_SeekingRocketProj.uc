class HxNet_SeekingRocketProj extends SeekingRocketProj;

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
    if (FlockIndex != 0 && Flock[1] == None)
    {
        class'HxNet_RocketProj'.static.PopulateFlock(Self);
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
    SetTimer(0.1, true);
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
            if (HxNet_SeekingRocketProjDummy(Dummies[i]) != None
                && HxNet_SeekingRocketProjDummy(Dummies[i]).Index == Index)
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
        class'HxNet_RocketProj'.static.ApplyDummyEffects(Self, Dummy);
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

defaultproperties
{
    InterpolationPeriod=0.30
}
