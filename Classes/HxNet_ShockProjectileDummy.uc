class HxNet_ShockProjectileDummy extends ShockProjectile;

simulated function Destroyed()
{
    if (ShockBallEffect != None)
    {
        ShockBallEffect.Destroy();
    }
    Super(Projectile).Destroyed();
}

defaultproperties
{
    bCollideActors=false
}
