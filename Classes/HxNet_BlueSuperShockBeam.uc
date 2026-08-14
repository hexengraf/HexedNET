class HxNet_BlueSuperShockBeam extends BlueSuperShockBeam;

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
    // TODO: why are super shock beams not net temporary? Normal beams are.
    // Does changing this to true has any hidden side-effects?
    bNetTemporary=true
}
