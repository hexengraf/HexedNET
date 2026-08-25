class HxNet_ShockProjFire extends ShockProjFire
    DependsOn(HxNTWeapon);

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

function DoFireEffect()
{
    local Vector HitLocation;
    local Vector HitNormal;
    local Vector Start;
    local Vector X;
    local Vector Y;
    local Vector Z;

    if (bBoostedAimSynchronization)
    {
        bBoostedAimSynchronization = false;
        Instigator.MakeNoise(1.0);
        GetAxes(BASAim, X, Y, Z);
        Start = BASStart + X * ProjSpawnOffset.X;
        if (!Weapon.WeaponCentered())
        {
            Start = Start + Weapon.Hand * Y * ProjSpawnOffset.Y + Z * ProjSpawnOffset.Z;
        }
        if (Weapon.Trace(HitLocation, HitNormal, Start, BASStart, false) != None)
        {
            Start = HitLocation;
        }
        SpawnProjectile(Start, BASAim);
    }
    else
    {
        Super.DoFireEffect();
    }
    ServerDelay = 0;
}

function Projectile SpawnProjectile(Vector Start, Rotator Dir)
{
    local Projectile P;

    if (Level.NetMode == NM_Client)
    {
        P = Weapon.Spawn(class'HxNet_ShockProjectileDummy',,, Start, Dir);
        return Client.TrackDummyProjectile(P, class'ShockRifle');
    }
    if (IsEnhancedNetcodeEnabled())
    {
        P = ExtrapolateProjectile(Start, Dir);
    }
    else
    {
        P = Super.SpawnProjectile(Start, Dir);
    }
    if (HexedNET != None)
    {
        HexedNET.RegisterShockProjectile(HxNet_ShockProjectile(P));
    }
    return P;
}

// TODO: handle bSwitchToZeroCollision
function Projectile ExtrapolateProjectile(Vector Start, Rotator Dir)
{
    local Vector Velocity;
    local Vector Extent;
    local Vector HitLocation;
    local Vector HitNormal;
    local Vector Origin;
    local Vector End;
    local Actor Hit;
    local float DeltaTime;
    local float TimeStep;

    Velocity = Vector(Dir) * class'ShockProjectile'.default.Speed;
    Extent = Vect(20, 20, 20);
    DeltaTime = Client.GetProjectilePing() + ServerDelay;
    Origin = Start;
    while (DeltaTime > 0)
    {
        TimeStep = FMin(BASE_TIMESTEP, DeltaTime);
        DeltaTime -= TimeStep;
        End = Start + Velocity * TimeStep;
        HexedNET.TimeTravel(DeltaTime);
        Hit = HexedNET.TimeTravelTrace(Weapon, HitLocation, HitNormal, End, Start, Extent);
        if (Hit != None)
        {
            if (Hit.IsA('PawnCollisionCopy'))
            {
                // TODO: what about self-inflicted splash damage if target is close?
                // By updating to collide in the current target location (instead of past location),
                // players might wrongfully avoid self-inflicted splash damage.
                HitLocation += PawnCollisionCopy(Hit).GetLocationDelta();
            }
            Start = HitLocation;
            break;
        }
        Start = End;
    }
    HexedNET.UnTimeTravel();
    return Super.SpawnProjectile(Start, Dir);
}

defaultproperties
{
    ProjectileClass=class'HxNet_ShockProjectile'
}
