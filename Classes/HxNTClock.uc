class HxNTClock extends Actor;

var float AverDT;

replication
{
    unreliable if (Role == Role_Authority)
        AverDT;
}

simulated event PostBeginPlay()
{
    // TODO: Why? And why here?
    class'ShieldFire'.default.AutoFireTestFreq = 0.05;
    Super.PostBeginPlay();
}

simulated function Tick(float DeltaTime)
{
    ServerTick(DeltaTime);
    default.AverDT = AverDT;
}

function ServerTick(float DeltaTime)
{
    AverDT = (9.0 * AverDT + DeltaTime) * 0.1;
}

defaultproperties
{
    bAlwaysRelevant=True
    RemoteRole=ROLE_SimulatedProxy
    bOnlyDirtyReplication=true
    NetUpdateFrequency=0.25
    NetPriority=3
    bHidden=true
}
