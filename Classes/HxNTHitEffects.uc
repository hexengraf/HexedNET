class HxNTHitEffects extends Effects;

var Vector HitLocation;
var Vector HitNormal;

replication
{
    reliable if (Role == ROLE_Authority && bNetInitial)
        HitLocation, HitNormal;
}

simulated function SpawnEffects();

simulated event PostNetBeginPlay()
{
    local PlayerController PC;

    if (Level.NetMode != NM_DedicatedServer)
    {
        LastRenderTime = Level.TimeSeconds;
        PC = Level.GetLocalPlayerController();
        if (PC == None || PC.Pawn == None || PC.Pawn != Instigator)
        {
            SpawnEffects();
        }
        else
        {
            LifeSpan = 0;
            Destroy();
        }
    }
}

simulated function SpawnExplosionDecal(class<Projector> DecalClass)
{
    local PlayerController PC;

    if (DecalClass != None)
    {
        if (DecalClass.default.CullDistance != 0)
        {
            PC = Level.GetLocalPlayerController();
            if (!PC.BeyondViewDistance(Location, DecalClass.default.CullDistance)
                || (Instigator != None && PC == Instigator.Controller)
                    && !PC.BeyondViewDistance(Location, 2 * DecalClass.default.CullDistance))
            {
                Spawn(DecalClass, Self,, Location, Rotator(-HitNormal));
            }
        }
        else
        {
            Spawn(DecalClass, Self,, Location, Rotator(-HitNormal));
        }
    }
}

defaultproperties
{
    DrawType=DT_None
    Physics=PHYS_None
    RemoteRole=ROLE_SimulatedProxy
    bNetInitialRotation=true
    bReplicateInstigator=true
    NetPriority=2.5
    LifeSpan=1.0
}
