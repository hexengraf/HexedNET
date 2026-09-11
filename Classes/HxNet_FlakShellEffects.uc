class HxNet_FlakShellEffects extends HxNTHitEffects;

simulated function SpawnEffects()
{
    local PlayerController PC;

    PlaySound(Sound'WeaponSounds.BExplosion1',, 3 * TransientSoundVolume);
    if (EffectIsRelevant(Location, false))
    {
        PC = Level.GetLocalPlayerController();
        if (PC.ViewTarget != None && VSize(PC.ViewTarget.Location - Location) < 3000)
        {
            Spawn(class'FlakExplosion',,, HitLocation + HitNormal * 16);
        }
        Spawn(class'FlashExplosion',,,HitLocation + HitNormal * 16);
        Spawn(class'RocketSmokeRing',,,HitLocation + HitNormal * 16, Rotator(HitNormal));
        if (class'FlakShell'.default.ExplosionDecal != None)
        {
            Spawn(class'FlakShell'.default.ExplosionDecal, Self,, HitLocation, rotator(-HitNormal));
        }
    }
}

defaultproperties
{
}
