class HxNet_GrenadeEffects extends HxNTHitEffects;

simulated function SpawnEffects()
{
    PlaySound(sound'WeaponSounds.BExplosion3',, 2.5 * TransientSoundVolume);
    if (EffectIsRelevant(Location, false))
    {
        Spawn(class'NewExplosionB',,, HitLocation, Rotator(Vect(0, 0, 1)));
        Spawn(class'Grenade'.default.ExplosionDecal, Self,, HitLocation, Rotator(-HitNormal));
    }
}

defaultproperties
{
}
