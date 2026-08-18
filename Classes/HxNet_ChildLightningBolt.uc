class HxNet_ChildLightningBolt extends ChildLightningBolt;

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
    bReplicateInstigator=True
    bSkipActorPropertyReplication=False
}
