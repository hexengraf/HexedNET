class HxNet_FlakFire extends FlakFire
    DependsOn(HxNTWeapon);

// TODO: Revisit this later, different values result in different amounts of error.
// Maybe it should be the average DeltaTime from the client? But then players with super high FPS
// and super high ping will cause an abusive amount of iterations.
const BASE_TIMESTEP = 0.02;

var float ServerDelay;
var private MutHexedNET HexedNET;
var private HxNTClient Client;
var private Vector BASStart;
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

function Vector GetProjectileStart(Vector StartTrace, rotator Dir)
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
            X = Vector(Aim);
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

function Projectile SpawnIndexedProjectile(Vector Start, Rotator Dir, int Index)
{
    local HxNet_FlakChunkDummy P;

    if (Level.NetMode == NM_Client)
    {
        P = Weapon.Spawn(class'HxNet_FlakChunkDummy',,, Start, Dir);
        if (P != None)
        {
            P.Index = Index;
            P.Bounces = RandomizeBounces();
        }
        return Client.TrackDummyProjectile(P, class'FlakCannon');
    }
    if (IsEnhancedNetcodeEnabled())
    {
        return ExtrapolateProjectile(Start, Dir, Index);
    }
    return SpawnProjectile(Start, Dir);
}

function Projectile ExtrapolateProjectile(Vector Start, Rotator Dir, int Index)
{
    local HxNet_FlakChunk P;
    local PhysicsVolume Volume;
    local Vector Velocity;
    local Vector HitLocation;
    local Vector HitNormal;
    local Vector Delta;
    local Vector End;
    local Actor Hit;
    local float DeltaTime;
    local float TimeStep;
    local int Bounces;
    local bool bFalling;

    Velocity = GetInitialVelocity(Start, Dir, Volume);
    DeltaTime = Client.GetProjectilePing() + ServerDelay;
    Bounces = RandomizeBounces();
    while (DeltaTime > 0)
    {
        TimeStep = FMin(BASE_TIMESTEP, DeltaTime);
        DeltaTime -= TimeStep;
        if (bFalling)
        {
            Delta = class'HxNTPhysics'.static.AdvanceFalling(Volume, Velocity, TimeStep);
        }
        else
        {
            Delta = Velocity * TimeStep;
        }
        End = Start + Delta;
        HexedNET.TimeTravel(DeltaTime);
        Hit = HexedNET.TimeTravelTrace(Weapon, HitLocation, HitNormal, End, Start,, bFalling);
        if (Hit != None)
        {
            if (HitWall(Hit))
            {
                if (Bounces > 0)
                {
                    bFalling = true;
                    Velocity = 0.65 * (Velocity - 2.0 * HitNormal * (Velocity dot HitNormal));
                    DeltaTime += (VSize(HitLocation - End) / VSize(Delta)) * TimeStep;
                    End = HitLocation;
                    --Bounces;
                }
                else
                {
                    Start = HitLocation;
                    // TODO: find a better way to handle chunks that finished bouncing
                    if (HitNormal.Z < Hit.MINFLOORZ)
                    {
                        Start -= Normal(Velocity) * 100;
                    }
                    break;
                }
            }
            else
            {
                if (Hit.IsA('PawnCollisionCopy'))
                {
                    HitLocation += PawnCollisionCopy(Hit).GetLocationDelta();
                }
                Start = HitLocation;
                break;
            }
        }
        Start = End;
        Volume = Level.GetPhysicsVolume(Start);
    }
    HexedNET.UnTimeTravel();
    P = HxNet_FlakChunk(SpawnProjectile(Start, Dir));
    if (P != None)
    {
        P.Index = Index;
        P.Bounces = Bounces;
        if (bFalling)
        {
            P.SetPhysics(PHYS_Falling);
            P.Velocity = Velocity;
            P.bBounce = Bounces > 0;
        }
    }
    return P;
}

final function bool HitWall(Actor Wall)
{
    return Wall.bStatic
        || Wall.bWorldGeometry
        || (Mover(Wall) != None && !Mover(Wall).bDamageTriggered);
}

final function Vector GetInitialVelocity(Vector Start, Rotator Dir, out PhysicsVolume Volume)
{
    local Vector Velocity;

    Velocity = Vector(Dir) * class'FlakChunk'.default.Speed;
    Volume = Level.GetPhysicsVolume(Start);
    if (Volume.bWaterVolume)
    {
        Velocity *= 0.65;
    }
    return Velocity;
}

final function int RandomizeBounces()
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
