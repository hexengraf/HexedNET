class HxNet_Grenade extends Grenade;

var HxNTClient Client;
var private HxRandomGeneratorAlt Generator;
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
    local Grenade G;

    WeaponInfo = Client.GetWeaponInfo(class'AssaultRifle');
    G = Grenade(WeaponInfo.MatchProjectile(Location));
    if (G != None)
    {
        InterpolatePredicted(G);
        G.Destroy();
    }
}

simulated function InterpolatePredicted(Grenade Predicted)
{
    if (Predicted != None && !Predicted.bDeleteMe)
    {
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

simulated function DoMove(Vector Offset)
{
    Move(Offset);
}

simulated function DoSetLocation(Vector NewLocation)
{
    SetLocation(NewLocation);
}

function SpawnRandomGenerator(int Seed)
{
    Generator = HxRandomGeneratorAlt(Level.ObjectPool.AllocateObject(
        class'HxRandomGeneratorAlt'));
    Generator.SetSeed(Seed);
    DeterministicRandSpin(25000);
}

simulated function HitWall(Vector HitNormal, Actor Wall)
{
    local Vector VNorm;
    local PlayerController PC;

    if (Pawn(Wall) != None || GameObjective(Wall) != None)
    {
        Explode(Location, HitNormal);
        return;
    }
    if (!bTimerSet)
    {
        SetTimer(ExplodeTimer, false);
        bTimerSet = true;
    }
    VNorm = (Velocity dot HitNormal) * HitNormal;
    Velocity = -VNorm * DampenFactor + (Velocity - VNorm) * DampenFactorParallel;
    DeterministicRandSpin(100000);
    DesiredRotation.Roll = 0;
    RotationRate.Roll = 0;
    Speed = VSize(Velocity);
    if (Speed < 20)
    {
        bBounce = False;
        PrePivot.Z = -1.5;
        SetPhysics(PHYS_None);
        DesiredRotation = Rotation;
        DesiredRotation.Roll = 0;
        DesiredRotation.Pitch = 0;
        SetRotation(DesiredRotation);
        if (Trail != None)
        {
            Trail.mRegen = false;
        }
    }
    else
    {
        if (Level.NetMode != NM_DedicatedServer && Speed > 250)
        {
            PlaySound(ImpactSound, SLOT_Misc);
        }
        else
        {
            bFixedRotationDir = false;
            bRotateToDesired = true;
            DesiredRotation.Pitch = 0;
            RotationRate.Pitch = 50000;
        }
        if (!Level.bDropDetail && Level.DetailMode != DM_Low
            && Level.TimeSeconds - LastSparkTime > 0.5 && EffectIsRelevant(Location, false))
        {
            PC = Level.GetLocalPlayerController();
            if (PC.ViewTarget != None && VSize(PC.ViewTarget.Location - Location) < 6000)
            {
                Spawn(HitEffectClass,,, Location, Rotator(HitNormal));
            }
            LastSparkTime = Level.TimeSeconds;
        }
    }
}

simulated function DeterministicRandSpin(float SpinRate)
{
    if (Generator != None)
    {
        DesiredRotation = Generator.RandRot();
        RotationRate.Yaw = SpinRate * 2 * Generator.RandFloat() - SpinRate;
        RotationRate.Pitch = SpinRate * 2 * Generator.RandFloat() - SpinRate;
        RotationRate.Roll = SpinRate * 2 * Generator.RandFloat() - SpinRate;
    }
    else
    {
        RandSpin(SpinRate);
    }
}

simulated event Destroyed()
{
    if (Generator != None)
    {
        Level.ObjectPool.FreeObject(Generator);
        Generator = None;
    }
    Super.Destroyed();
}

simulated function Explode(Vector HitLocation, Vector HitNormal)
{
    local HxNet_GrenadeEffects Effects;

    if (Role == ROLE_Authority && TickCount < 2)
    {
        BlowUp(HitLocation);
        Effects = Spawn(class'HxNet_GrenadeEffects',,, Location, Rotation);
        Effects.HitLocation = HitLocation;
        Effects.HitNormal = HitNormal;
        Destroy();
    }
    else
    {
        Super.Explode(HitLOcation, HitNormal);
    }
}

defaultproperties
{
    InterpolationPeriod=0.15
}
