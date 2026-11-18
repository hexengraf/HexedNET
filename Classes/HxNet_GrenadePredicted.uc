class HxNet_GrenadePredicted extends Grenade;

var HxNTWeaponInfo WeaponInfo;
var HxRandomGenerator Generator;
var bool bRemoved;

simulated event Destroyed()
{
    if (!bRemoved && WeaponInfo != None)
    {
        WeaponInfo.RemovePredictedProjectile(Self);
    }
    if (Generator != None)
    {
        Level.ObjectPool.FreeObject(Generator);
        Generator = None;
    }
    Super.Destroyed();
}

function SpawnRandomGenerator(HxRandomGeneratorAlt Seeder)
{
    Generator = HxRandomGenerator(Level.ObjectPool.AllocateObject(class'HxRandomGenerator'));
    Generator.SetSeed(Seeder.RandInt(), Seeder.RandInt(), Seeder.RandInt(), Seeder.RandInt());
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

simulated function Explode(Vector HitLocation, Vector HitNormal)
{
    Super(Grenade).Explode(HitLocation, HitNormal);
}

simulated function BlowUp(Vector HitLocation)
{
}

defaultproperties
{
    bNetTemporary=false
}
