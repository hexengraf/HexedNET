class HxNTPhysics extends Object
    abstract;

static final function Vector AdvanceFalling(PhysicsVolume Volume,
                                            out Vector Velocity,
                                            float DeltaTime)
{
    if (Volume.bWaterVolume)
    {
        Velocity *= 1.0 - Volume.FluidFriction * DeltaTime;
    }
    Velocity += Volume.Gravity * DeltaTime * 0.5;
    return (Velocity + Volume.ZoneVelocity) * DeltaTime;
}

static final function Vector AdjustFallingVelocity(PhysicsVolume Volume,
                                                   Vector PreviousVelocity,
                                                   Vector Delta,
                                                   float DeltaTime)
{
    local Vector Velocity;

    Velocity = Delta / DeltaTime - Volume.ZoneVelocity;
    if (Velocity.Z < PreviousVelocity.Z || PreviousVelocity.Z >= 0)
    {
        Velocity = 2 * Velocity - PreviousVelocity;
    }
    if (VSize(Velocity) > Volume.TerminalVelocity)
    {
        Velocity = Normal(Velocity) * Volume.TerminalVelocity;
    }
    return Velocity;
}

static final function bool SwitchToZeroCollision(ProjectileFire Fire,
                                                 Actor Hit,
                                                 Vector Start,
                                                 Vector End)
{
    local Actor OtherHit;
    local Vector HitLocation;
    local Vector HitNormal;
    local Vector Range;

    if (Hit.bBlockZeroExtentTraces
        && (Hit.StaticMesh == None
            || (StaticMeshActor(Hit) != None && !StaticMeshActor(Hit).bExactProjectileCollision)))
    {
        return false;
    }
    Range = Normal(Start - End) * 100;
    OtherHit = Fire.Trace(HitLocation, HitNormal, Start + Range, End, true);
    if (OtherHit == None)
    {
        OtherHit = Fire.Trace(HitLocation, HitNormal, End, Start + Range, true);
    }
    else
    {
        OtherHit = Fire.Trace(HitLocation, HitNormal, End, HitLocation, true);
    }
    return OtherHit == None;
}

static final function SafeSetPosition(Projectile P, Vector Start, Rotator Dir)
{
    DisableCollision(P);
    P.SetRotation(Dir);
    P.SetLocation(Start);
    RestoreCollision(P);
}

static final function DisableCollision(Projectile P)
{
    P.bCollideWorld = false;
    P.SetCollision(false, false);
}

static final function RestoreCollision(Projectile P)
{
    P.bCollideWorld = P.default.bCollideWorld;
    P.SetCollision(P.default.bCollideActors, P.default.bBlockActors);

}

static final function Projectile SpawnProjectile(ProjectileFire Fire,
                                                 Vector Start,
                                                 Rotator Dir,
                                                 Vector ZeroHitLocation,
                                                 Actor ZeroCollider)
{
    Local Projectile P;

    if (ZeroCollider == None)
    {
        P = Fire.SpawnProjectile(Start, Dir);
    }
    else
    {
        P = Fire.SpawnProjectile(ZeroHitLocation, Dir);
        if (P != None)
        {
            P.SetCollisionSize(0, 0);
            P.bSwitchToZeroCollision = false;
            P.ZeroCollider = ZeroCollider;
            P.Move(Start - ZeroHitLocation);
        }
    }
    return P;
}

static final function Vector GetClearHitLocation(Vector HitLocation,
                                                 Vector HitNormal,
                                                 Vector Direction,
                                                 float Clearance,
                                                 float Limit)
{
    local float Ratio;

    Ratio = Abs(Direction Dot HitNormal);
    Limit = 1 / Limit;
    if (Ratio < Limit)
    {
        return HitLocation - (Direction * Limit);
    }
    return HitLocation - (Direction * (Clearance / Ratio));
}

defaultproperties
{
}
