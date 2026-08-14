class HxNet_ShockProjectileDummy extends ShockProjectile;

simulated function Destroyed()
{
    if (ShockBallEffect != None)
    {
        ShockBallEffect.Destroy();
    }
    super(Projectile).Destroyed();
}

defaultproperties
{
    bCollideActors=False
}
