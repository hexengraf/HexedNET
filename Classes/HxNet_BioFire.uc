class HxNet_BioFire extends BioFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTFallingProjectileFire.uci

function Vector GetProjectileVelocity(Rotator Dir)
{
    local Vector Velocity;

    Velocity = Vector(Dir) * ProjectileClass.default.Speed;
    Velocity.Z += ProjectileClass.default.TossZ;
    return Velocity;
}

function Vector GetProjectileExtent()
{
    local Vector Extent;

    Extent = Vect(1, 1, 0);
    Extent *= ProjectileClass.default.CollisionRadius;
    Extent.Z = ProjectileClass.default.CollisionHeight;
    return Extent;
}

defaultproperties
{
    WeaponClass=class'BioRifle'
    DummyProjectileClass=class'HxNet_BioGlobDummy'
    ExtrapolatedProjectileClass=class'HxNet_BioGlob'
}
