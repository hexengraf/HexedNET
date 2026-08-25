class HxNet_FlakChunk extends FlakChunk;

const INTERPOLATION_PERIOD = 0.30;

var int Index;
var private MutHexedNET MutatorOwner;
var private Vector DummyOffset;
var private float ElapsedInterpolationTime;
var private bool bInterpolateDummy;

replication
{
    unreliable if (bDemoRecording)
        DoMove, DoSetLocation;

    reliable if (Role == ROLE_Authority && bNetInitial)
        Index;
}

simulated function PostNetBeginPlay()
{
    local PlayerController PC;
    local HxNTClient Client;

    Super.PostNetBeginPlay();
    if (Level.NetMode == NM_Client)
    {
        PC = Level.GetLocalPlayerController();
        foreach DynamicActors(class'HxNTClient', Client)
        {
            if (Client.IsEnhancedNetcodeEnabled()
                && PC != None && PC.Pawn != None && PC.Pawn == Instigator)
            {
                SearchPredictedProjectile(Client);
            }
            break;
        }
    }
}

simulated function SearchPredictedProjectile(HxNTClient Client)
{
    local array<Projectile> Dummies;
    local float MinDistance;
    local float Distance;
    local int DummyIndex;
    local int i;

    Dummies = Client.GetDummies(class'FlakCannon');
    if (Dummies.Length > 0)
    {
        DummyIndex = -1;
        MinDistance = MaxInt;
        for (i = 0; i < Dummies.Length; ++i)
        {
            if (HxNet_FlakChunkDummy(Dummies[i]) != None
                && HxNet_FlakChunkDummy(Dummies[i]).Index == Index)
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
            InterpolateDummy(FlakChunk(Dummies[DummyIndex]));
            Client.DestroyDummyProjectile(class'FlakCannon', DummyIndex);
        }
    }
}

simulated function InterpolateDummy(FlakChunk Dummy)
{
    if (Dummy != None)
    {
        bInterpolateDummy = true;
        DummyOffset = Location - Dummy.Location;
        if (Trail != None)
        {
            Trail.mRegen = false;
            Trail.SetPhysics(PHYS_None);
        }
        if (Dummy.Trail != None)
        {
            Trail = Dummy.Trail;
            Trail.SetOwner(Self);
            Dummy.Trail = None;
        }
        DoSetLocation(Dummy.Location);
        SetRotation(Dummy.Rotation);
    }
}

simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    if (bInterpolateDummy)
    {
        DeltaTime = FMin(DeltaTime, INTERPOLATION_PERIOD - ElapsedInterpolationTime);
        if (DeltaTime > 0)
        {
            DoMove(DummyOffset * DeltaTime / INTERPOLATION_PERIOD);
            ElapsedInterpolationTime += DeltaTime;
            bInterpolateDummy = ElapsedInterpolationTime < INTERPOLATION_PERIOD;
        }
        else
        {
            bInterpolateDummy = false;
        }
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
}
