class HxNet_ShockProjFire extends ShockProjFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTBaseProjectileFire.uci

function DoFireEffect()
{
    DoBaseFireEffect();
}

function Projectile SpawnHexedProjectile(Vector Start, Rotator Dir, optional int Index)
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
        P = SpawnProjectile(Start, Dir);
    }
    if (HexedNET != None)
    {
        HexedNET.RegisterShockProjectile(HxNet_ShockProjectile(P));
    }
    return P;
}

// TODO: handle bSwitchToZeroCollision without causing unexpected passthrough.
function Projectile ExtrapolateProjectile(Vector Start, Rotator Dir)
{
    local Projectile P;
    local Vector Velocity;
    local Vector Extent;
    local Vector End;
    local Actor Hit;
    local Vector HitLocation;
    local Vector HitNormal;
    local float DeltaTime;
    local float ElapsedTime;
    local float TimeStep;

    Velocity = Vector(Dir) * ProjectileClass.default.Speed;
    Extent = Vect(10, 10, 10);
    DeltaTime = Client.GetProjectilePing() + ServerDelay;
    while (DeltaTime > 0)
    {
        TimeStep = HexedNET.GetTimeStep(DeltaTime);
        DeltaTime -= TimeStep;
        ElapsedTime += TimeStep;
        if (ElapsedTime >= 0.4)
        {
            Extent = Vect(20, 20, 20);
        }
        End = Start + Velocity * TimeStep;
        HexedNET.TimeTravel(DeltaTime);
        Hit = HexedNET.TimeTravelTrace(Weapon, HitLocation, HitNormal, End, Start, Extent);
        if (Hit != None)
        {
            if (Hit.IsA('PawnCollisionCopy'))
            {
                HitLocation += PawnCollisionCopy(Hit).GetLocationDelta();
            }
            Start = HitLocation;
            break;
        }
        Start = End;
    }
    HexedNET.UnTimeTravel();
    P = SpawnProjectile(Start, Dir);
    if (P != None)
    {
        if (ElapsedTime >= 0.4)
        {
            P.SetCollisionSize(20, 20);
        }
        P.SetTimer(FMax(0, ElapsedTime - 0.4), false);
    }
    return P;
}

defaultproperties
{
    ProjectileClass=class'HxNet_ShockProjectile'
}
