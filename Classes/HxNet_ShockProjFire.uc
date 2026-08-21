class HxNet_ShockProjFire extends ShockProjFire
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
    local Vector Origin;
    local Vector HitLocation;
    local Vector HitNormal;
    local vector End;
    local Actor Hit;
    local float DeltaTime;
    local float ForwardTime;

    if (Level.NetMode == NM_Client)
    {
        return SpawnDummyProjectile(Start, Dir);
    }
    if (!IsEnhancedNetcodeEnabled() || Weapon.Owner == None)
    {
        return RegisterProjectile(Super.SpawnProjectile(Start, Dir));
    }
    DeltaTime = Client.GetProjectilePing() + ServerDelay;
    Origin = Start;
    for (ForwardTime = 0.00; ForwardTime <= DeltaTime; ForwardTime += BASE_TIMESTEP)
    {
        End = Start + Extrapolate(Dir, BASE_TIMESTEP);
        HexedNET.TimeTravel(DeltaTime - ForwardTime);
        Hit = HexedNET.TimeTravelTrace(Weapon, HitLocation, HitNormal, End, Start);
        if (Hit != None)
        {
            if (Hit.IsA('PawnCollisionCopy'))
            {
                // TODO: what about self-inflicted splash damage if target is close?
                // By updating to collide in the current target location (instead of past location),
                // players might wrongfully avoid self-inflicted splash damage.
                Start = HitLocation + PawnCollisionCopy(Hit).GetLocationDelta() - Vector(Dir) * 20;
            }
            else
            {
                Start = GetStartOnHit(Origin, HitLocation, Dir);
            }
            break;
        }
        Start = End;
    }
    HexedNET.UnTimeTravel();
    if (Hit == None && ForwardTime > DeltaTime)
    {
        End = Start + Extrapolate(Dir, DeltaTime - ForwardTime + BASE_TIMESTEP);
        if (Weapon.Trace(HitLocation, HitNormal, End, Start, false) != None)
        {
            Start = GetStartOnHit(Origin, HitLocation, Dir);
        }
        else
        {
            Start = End;
        }
    }
    return RegisterProjectile(Super.SpawnProjectile(Start, Dir));
}

function Projectile SpawnDummyProjectile(Vector Start, Rotator Dir)
{
    local Projectile P;

    P = Weapon.Spawn(class'HxNet_ShockProjectileDummy',,, Start, Dir);
    if (P != None)
    {
        Client.TrackDummyProjectile(P, class'ShockRifle');
    }
    return P;
}

function Projectile RegisterProjectile(Projectile P)
{
    if (HexedNET != None)
    {
        HexedNET.RegisterShockProjectile(HxNet_ShockProjectile(P));
    }
    return P;
}

static final function vector GetStartOnHit(vector Origin, vector HitLocation, rotator Dir)
{
    // TODO: only doing this to properly register self-inflicted damage when shooting against walls.
    // Is there a better way to handle this? Also, why subtract Vector(Dir) * 20? This is used in
    // other projectiles as well. Does hit not register if spawned almost inside the target?
    if (VSize(HitLocation - Origin) > class'HxNet_ShockProjectile'.default.DamageRadius)
    {
        return HitLocation - Vector(Dir) * 20;
    }
    return Origin;
}

static final function vector Extrapolate(rotator Dir, float DeltaTime)
{
    return vector(Dir) * class'HxNet_ShockProjectile'.default.Speed * DeltaTime;
}

defaultproperties
{
    ProjectileClass=class'HxNet_ShockProjectile'
}
