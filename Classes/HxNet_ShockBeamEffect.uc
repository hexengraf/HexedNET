class HxNet_ShockBeamEffect extends ShockBeamEffect;

simulated function SpawnEffects()
{
    if (Role < ROLE_Authority
        && ((Instigator != None && Instigator.IsLocallyControlled())
            || (Pawn(Owner) != None && Pawn(Owner).IsLocallyControlled())))
    {
        Destroy();
    }
    else
    {
        Super.SpawnEffects();
    }
}

defaultproperties
{
}
