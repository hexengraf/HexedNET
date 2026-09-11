class HxNet_RocketProjEffects extends HxNTHitEffects;

simulated function SpawnEffects()
{
    local PlayerController PC;

    PlaySound(sound'WeaponSounds.BExplosion3',, 2.5 * TransientSoundVolume);
    if (EffectIsRelevant(Location, false))
    {
        Spawn(class'NewExplosionA',,, HitLocation + HitNormal * 20, Rotator(HitNormal));
        PC = Level.GetLocalPlayerController();
        if (PC.ViewTarget != None && VSize(PC.ViewTarget.Location - Location) < 5000)
        {
            Spawn(class'ExplosionCrap',,, HitLocation + HitNormal * 20, Rotator(HitNormal));
        }
    }
    SpawnExplosionDecal(class'RocketProj'.default.ExplosionDecal);
}

defaultproperties
{
}
