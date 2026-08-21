class HxNet_FlakAltFire extends FlakAltFire;

// TODO: Revisit this later, different values result in different amounts of error.
// Maybe it should be the average DeltaTime from the client? But then players with super high FPS
// and super high ping will cause an abusive amount of iterations.
const BASE_TIMESTEP = 0.02;

var float ServerDelay;
var private MutHexedNET HexedNET;
var private HxNTClient Client;
var private Vector BASStart;
var private Rotator BASAim;
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

function Vector GetProjectileStart(Vector StartTrace, Rotator Dir)
{
    local Vector HitLocation;
    local Vector HitNormal;
    local Vector Start;
    local Vector X;
    local Vector Y;
    local Vector Z;

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
    local Vector Start;
    local Vector X;
    local Rotator Aim;
    local float Theta;
    local int SpawnCount;
    local int i;

    if (!class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client))
    {
        Super.DoFireEffect();
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
            X = Vector(Aim);
            for (i = 0; i < SpawnCount; i++)
            {
                Aim.Yaw = Spread * (Client.GetRandomFloat() - 0.5);
                Aim.Pitch = Spread * (Client.GetRandomFloat() - 0.5);
                Aim.Roll = Spread * (Client.GetRandomFloat() - 0.5);
                SpawnProjectile(Start, Rotator(X >> Aim));
            }
            break;
        case SS_Line:
            for (i = 0; i < SpawnCount; i++)
            {
                Theta = Spread * PI / 32768 * (i - float(SpawnCount - 1) / 2.0);
                X.X = Cos(Theta);
                X.Y = Sin(Theta);
                X.Z = 0.0;
                SpawnProjectile(Start, Rotator(X >> Aim));
            }
            break;
        default:
            SpawnProjectile(Start, Aim);
            break;
    }
    ServerDelay = 0;
}

function Projectile SpawnProjectile(Vector Start, Rotator Dir)
{
    local Projectile P;
    local Vector Velocity;

    if (Level.NetMode == NM_Client)
    {
        P = Weapon.Spawn(class'HxNet_FlakShellDummy',,, Start, Dir);
        if (P != None)
        {
            Client.TrackDummyProjectile(P, class'FlakCannon');
        }
        return P;
    }
    if (IsEnhancedNetcodeEnabled())
    {
        Extrapolate(Start, Dir, Velocity);
        P = Super.SpawnProjectile(Start, Dir);
        P.Velocity = Velocity;
        return P;
    }
    return Super.SpawnProjectile(Start, Dir);
}

function Extrapolate(out Vector Start, out Rotator Dir, out Vector Velocity)
{
    local PhysicsVolume Volume;
    local Vector HitLocation;
    local Vector HitNormal;
    local Vector End;
    local Actor Hit;
    local float DeltaTime;
    local float RemainingTime;
    local float TimeStep;
    local bool bSpawnedOnWater;

    Velocity = Vector(Dir) * class'FlakShell'.default.Speed;
    Velocity.Z += class'FlakShell'.default.TossZ;
    Volume = Level.GetPhysicsVolume(Start);
    bSpawnedOnWater = Volume.bWaterVolume;
    DeltaTime = Client.GetProjectilePing() + ServerDelay;
    RemainingTime = DeltaTime;
    while (RemainingTime > 0)
    {
        TimeStep = FMin(BASE_TIMESTEP, RemainingTime);
        RemainingTime -= TimeStep;
        End = class'HxNTWeapon'.static.ExtrapolateFalling(Volume, Start, TimeStep, Velocity);
        HexedNET.TimeTravel(DeltaTime - RemainingTime);
        Hit = HexedNET.TimeTravelTrace(Weapon, HitLocation, HitNormal, End, Start);
        if (Hit != None)
        {
            // TODO: Is - Vector(Dir) * 20 really needed?
            Start = HitLocation - Vector(Dir) * 20;
            if (Hit.IsA('PawnCollisionCopy'))
            {
                Start += PawnCollisionCopy(Hit).GetLocationDelta();
            }
            break;
        }
        Start = End;
        Volume = Level.GetPhysicsVolume(Start);
    }
    HexedNET.UnTimeTravel();
    if (!bSpawnedOnWater)
    {
        Dir = Rotator(Velocity);
    }
}

defaultproperties
{
    ProjectileClass=Class'HxNet_FlakShell'
}
