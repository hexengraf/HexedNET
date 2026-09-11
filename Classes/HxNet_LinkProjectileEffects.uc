class HxNet_LinkProjectileEffects extends HxNTHitEffects;

var bool bYellow;

replication
{
    reliable if (Role == ROLE_Authority && bNetInitial)
        bYellow;
}

simulated function SpawnEffects()
{
    if (EffectIsRelevant(Location, false))
    {
        if (bYellow)
        {
            Spawn(class'LinkProjSparksYellow',,, HitLocation, Rotator(HitNormal));
        }
        else
        {
            Spawn(class'LinkProjSparks',,, HitLocation, Rotator(HitNormal));
        }
    }
    SpawnExplosionDecal(class'LinkProjectile'.default.ExplosionDecal);
    PlaySound(Sound'WeaponSounds.BioRifle.BioRifleGoo2');
}

defaultproperties
{
}
