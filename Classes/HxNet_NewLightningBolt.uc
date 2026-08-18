class HxNet_NewLightningBolt extends NewLightningBolt;

simulated function PostNetBeginPlay()
{
    if (Role < Role_Authority && Instigator != None && Instigator.IsLocallyControlled())
    {
        Destroy();
    }
    else
    {
        Super.PostNetBeginPlay();
    }
}

defaultproperties
{
    bSkipActorPropertyReplication=false
}
