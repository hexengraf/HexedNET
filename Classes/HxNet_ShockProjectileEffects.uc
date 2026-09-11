class HxNet_ShockProjectileEffects extends HxNTHitEffects;

var private ShockBall ShockBallEffect;
var private bool bSelfDestroy;

simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    if (ShockBallEffect != None)
    {
        if (bSelfDestroy)
        {
            ShockBallEffect.Kill();
            ShockBallEffect = None;
            LifeSpan = 0;
            Destroy();
        }
        bSelfDestroy = true;
    }
}

simulated function SpawnEffects()
{
    PlaySound(Sound'WeaponSounds.ShockRifle.ShockRifleExplosion', SLOT_Misc);
    ShockBallEffect = Spawn(class'ShockBall', Self);
    if (EffectIsRelevant(Location, false))
    {
        Spawn(class'ShockExplosionCore',,, Location);
        if (!Level.bDropDetail && (Level.DetailMode != DM_Low))
        {
            Spawn(class'ShockExplosion',,, Location);
        }
    }
    SpawnExplosionDecal(class'ShockProjectile'.default.ExplosionDecal);
}

defaultproperties
{
    DrawType=DT_Sprite
    DrawScale=0.700000
    Style=STY_Translucent
    Texture=Texture'XEffectMat.Shock.shock_core_low'
    Skins(0)=Texture'XEffectMat.Shock.shock_core_low'
}
