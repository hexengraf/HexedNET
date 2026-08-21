class HxNet_FlakFire extends FlakFire
    DependsOn(HxNTWeapon);

// TODO: Revisit this later, different values result in different amounts of error.
// Maybe it should be the average DeltaTime from the client? But then players with super high FPS
// and super high ping will cause an abusive amount of iterations.
const BASE_TIMESTEP = 0.02;

var float ServerDelay;
var private MutHexedNET HexedNET;
var private HxNTClient Client;
var private vector BASStart;
var private rotator BASAim;
var private bool bBoostedAimSynchronization;

function PreBeginPlay()
{
    Super.PreBeginPlay();
    foreach Weapon.DynamicActors(class'MutHexedNET', HexedNET) break;
    class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client);
}

function bool IsEnhancedNetcodeEnabled()
{
    return class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        && Client.IsEnhancedNetcodeEnabled();
}

function PlayFiring()
{
    local float ProjectileDelay;

    Super.PlayFiring();
    if (Level.NetMode == NM_Client && IsEnhancedNetcodeEnabled()
        && Instigator.IsLocallyControlled()
        && Client.ShouldSpawnDummyProjectile())
    {
        ProjectileDelay = Client.GetProjectileDelay();
        if (ProjectileDelay > 0)
        {
            if (TimerInterval > 0)
            {
                DoFireEffect();
            }
            if (!bBoostedAimSynchronization)
            {
                BASStart = Instigator.Location + Instigator.EyePosition();
                BASAim = AdjustAim(BASStart, AimError);
                bBoostedAimSynchronization = true;
            }
            SetTimer(ProjectileDelay, false);
        }
        else
        {
            DoFireEffect();
        }
    }
}

function Timer()
{
    DoFireEffect();
}

function ApplyBAS(HxNTWeapon.HxBAS BAS)
{
    class'HxNTWeapon'.static.DecodeBAS(BAS, BASStart, BASAim);
    bBoostedAimSynchronization = HexedNET == None || HexedNET.IsReasonable(Weapon, BASStart);
}

function vector GetProjectileStart(vector StartTrace, rotator Dir)
{
    local vector HitLocation;
    local vector HitNormal;
    local vector Start;
    local vector X;
    local vector Y;
    local vector Z;

    GetAxes(Dir, X, Y, Z);
    Start = StartTrace + X * ProjSpawnOffset.X;
    if (!Weapon.WeaponCentered())
    {
        Start += Weapon.Hand * Y * ProjSpawnOffset.Y + Z * ProjSpawnOffset.Z;
    }
    if (Weapon.Trace(HitLocation, HitNormal, Start, StartTrace, false) != None)
    {
        return HitLocation;
    }
    return Start;
}

function DoFireEffect()
{
    local vector Start;
    local vector X;
    local rotator Aim;
    local float Theta;
    local int SpawnCount;
    local int i;

    if (!class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client))
    {
        Super.DoFireEffect();
        ServerDelay = 0;
        return;
    }
    Instigator.MakeNoise(1.0);
    if (bBoostedAimSynchronization)
    {
        bBoostedAimSynchronization = false;
        Start = GetProjectileStart(BASStart, BASAim);
        Aim = BASAim;
    }
    else
    {
        if (Instigator.Controller != None)
        {
            Start = GetProjectileStart(
                Instigator.Location + Instigator.EyePosition(), Instigator.Controller.Rotation);
        }
        else
        {
            Start = GetProjectileStart(
                Instigator.Location + Instigator.EyePosition(), Instigator.Rotation);
        }
        Aim = AdjustAim(Start, AimError);
    }
    SpawnCount = Max(1, ProjPerFire * int(Load));
    switch (SpreadStyle)
    {
        case SS_Random:
            X = vector(Aim);
            for (i = 0; i < SpawnCount; i++)
            {
                Aim.Yaw = Spread * (Client.GetRandomFloat() - 0.5);
                Aim.Pitch = Spread * (Client.GetRandomFloat() - 0.5);
                Aim.Roll = Spread * (Client.GetRandomFloat() - 0.5);
                SpawnIndexedProjectile(Start, Rotator(X >> Aim), i);
            }
            break;
        case SS_Line:
            for (i = 0; i < SpawnCount; i++)
            {
                Theta = Spread * PI / 32768 * (i - float(SpawnCount - 1) / 2.0);
                X.X = Cos(Theta);
                X.Y = Sin(Theta);
                X.Z = 0.0;
                SpawnIndexedProjectile(Start, Rotator(X >> Aim), i);
            }
            break;
        default:
            SpawnIndexedProjectile(Start, Aim, 0);
            break;
    }
    ServerDelay = 0;
}

function Projectile SpawnIndexedProjectile(vector Start, Rotator Dir, int Index)
{
    local Projectile P;
    local Vector Velocity;
    local Rotator RandomRotation;
    local int Bounces;
    local bool bBounced;

    if (Level.NetMode == NM_Client)
    {
        P = Weapon.Spawn(class'HxNet_FlakChunkDummy',,, Start, Dir);
        if (HxNet_FlakChunkDummy(P) != None)
        {
            Bounces = RandomizeBounces();
            RandomRotation = Client.GetRandomRotator();
            HxNet_FlakChunkDummy(P).Randomize(RandomRotation, Index, Bounces);
            Client.TrackDummyProjectile(P, class'FlakCannon');
        }
        return P;
    }
    if (IsEnhancedNetcodeEnabled())
    {
        bBounced = Extrapolate(Start, Dir, Velocity, Bounces);
        RandomRotation = Client.GetRandomRotator();
        P = SpawnProjectile(Start, Dir);
        if (HxNet_FlakChunk(P) != None)
        {
            HxNet_FlakChunk(P).Randomize(RandomRotation, Index, Bounces, bBounced);
            if (bBounced)
            {
                P.Velocity = Velocity;
            }
        }
        return P;
    }
    return SpawnProjectile(Start, Dir);
}

function bool Extrapolate(out Vector Start, out Rotator Dir, out Vector Velocity, out int Bounces)
{
    local PhysicsVolume Volume;
    local Vector HitLocation;
    local Vector HitNormal;
    local Vector End;
    local Actor Hit;
    local float DeltaTime;
    local float RemainingTime;
    local float TimeStep;
    local bool bBounced;

    Velocity = vector(Dir) * class'FlakChunk'.default.Speed;
    DeltaTime = Client.GetProjectilePing() + ServerDelay;
    RemainingTime = DeltaTime;
    Bounces = RandomizeBounces();
    Volume = Level.GetPhysicsVolume(Start);
    if (Volume.bWaterVolume)
    {
        Velocity *= 0.65;
    }
    while (RemainingTime > 0)
    {
        TimeStep = FMin(BASE_TIMESTEP, RemainingTime);
        RemainingTime -= TimeStep;
        if (bBounced)
        {
            End = class'HxNTWeapon'.static.ExtrapolateFalling(Volume, Start, TimeStep, Velocity);
        }
        else
        {
            End = Start + Velocity * TimeStep;
        }
        HexedNET.TimeTravel(DeltaTime - RemainingTime);
        Hit = HexedNET.TimeTravelTrace(Weapon, HitLocation, HitNormal, End, Start);
        if (Hit != None)
        {
            if (Hit.bStatic || Hit.bWorldGeometry)
            {
                RemainingTime += (VSize(HitLocation - End) / VSize(Start - End)) * TimeStep;
                bBounced = true;
                End = HitLocation;
                if (Bounces > 0)
                {
                    Velocity = 0.65 * (Velocity - 2.0 * HitNormal * (Velocity dot HitNormal));
                    --Bounces;
                }
                else
                {
                    Start = End;
                    break;
                }
            }
            else
            {
                // TODO: Is - Vector(Dir) * 20 really needed?
                Start = HitLocation - Vector(Dir) * 20;
                if (Hit.IsA('PawnCollisionCopy'))
                {
                    Start += PawnCollisionCopy(Hit).GetLocationDelta();
                }
                break;
            }
        }
        Start = End;
        Volume = Level.GetPhysicsVolume(Start);
    }
    HexedNET.UnTimeTravel();
    return bBounced;
}

function int RandomizeBounces()
{
    local float R;

    R = Client.GetRandomFloat();
    if (R > 0.75)
    {
        return 2;
    }
    if (R > 0.25)
    {
        return 1;
    }
    return 0;
}

defaultproperties
{
    ProjectileClass=class'HxNet_FlakChunk'
}
