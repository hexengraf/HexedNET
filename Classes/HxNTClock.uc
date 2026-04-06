class HxNTClock extends Actor;

const AVERDT_SEND_PERIOD = 4.00;

var float DT;
var float AverDT;
var byte ClientCounter;

var private byte ServerCounter;
var private float Timestamps[256];
var private float LastReplicatedAverDT;

replication
{
    unreliable if (Role == Role_Authority)
        ServerCounter, AverDT;
}

simulated function PostBeginPlay()
{
    class'ShieldFire'.default.AutoFireTestFreq = 0.05;
    Super.PostBeginPlay();
}

simulated function Tick(float DeltaTime)
{
    DT += DeltaTime;
    if ((ServerCounter - ClientCounter) % 256 < 128)
    {
        ClientCounter = ServerCounter;
        DT = 0.00;
    }
    default.AverDT = AverDT;
}

function Update(float CurrentTimestamp, float CurrentAverDT)
{
    if (CurrentTimestamp > LastReplicatedAverDT + AVERDT_SEND_PERIOD)
    {
        AverDT = CurrentAverDT;
        LastReplicatedAverDT = CurrentTimestamp;
    }
    ++ServerCounter;
    Timestamps[ServerCounter] = CurrentTimestamp;
}

function float GetTimestamp(byte Index)
{
    return Timestamps[Index];
}

defaultproperties
{
    bAlwaysRelevant=True
    RemoteRole=ROLE_SimulatedProxy
    bOnlyDirtyReplication=true
    NetUpdateFrequency=100.0
    NetPriority=3
    bHidden=true
}
