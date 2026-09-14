class HxNet_FlakChunk extends FlakChunk;

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

    Super.PostNetBeginPlay();
    if (Level.NetMode == NM_Client && Client != None && Client.WantsPingCompensation())
    {
        SearchDummyProjectile();
    }
}

simulated function SearchDummyProjectile()
{
    local HxNTWeaponInfo WeaponInfo;
    local FlakChunk Chunk;

    WeaponInfo = Client.GetWeaponInfo(class'FlakCannon');
    Chunk = FlakChunk(WeaponInfo.MatchProjectileFull(Location, class'HxNet_FlakChunkDummy', Index));
    if (Chunk != None)
    {
        InterpolateDummy(Chunk);
        Chunk.Destroy();
    }
}

simulated function InterpolateDummy(FlakChunk Dummy)
{
    if (Dummy != None)
    {
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
        bInterpolate = true;
        InterpolationOffset = Location - Dummy.Location;
        DoSetLocation(Dummy.Location);
        SetRotation(Dummy.Rotation);
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
