class HxNTClock extends Actor;

const AVERDT_SEND_PERIOD = 4.00;

var float ServerAverDT;
var float ServerTimestamp;

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
    Update(DeltaTime);
    DT += DeltaTime;
    if ((ServerCounter - ClientCounter) % 256 < 128)
    {
        ClientCounter = ServerCounter;
        DT = 0.00;
    }
    default.AverDT = AverDT;
}

function Update(float DeltaTime)
{
    ServerTimestamp += DeltaTime;
    ServerAverDT = (9.0 * ServerAverDT + DeltaTime) * 0.1;
    if (ServerTimestamp > LastReplicatedAverDT + AVERDT_SEND_PERIOD)
    {
        AverDT = ServerAverDT;
        LastReplicatedAverDT = ServerTimestamp;
    }
    ++ServerCounter;
    Timestamps[ServerCounter] = ServerTimestamp;
}

function float GetTimestamp(byte Index)
{
    return Timestamps[Index];
}

function float GetPingDT(byte ClientCounter, float DT)
{
    return ServerTimestamp - Timestamps[ClientCounter] - DT + (0.5 * ServerAverDT);
}

function bool IsReasonable(Weapon W, Vector V)
{
    local vector LocDiff;

    if (Pawn(W.Owner) == None)
    {
        return true;
    }
    LocDiff = V - (Pawn(W.Owner).Location + Pawn(W.Owner).EyePosition());
    // clErr = (LocDiff dot LocDiff);
    // if (clErr > 500.0*NETClock.ServerAverDT)
        // PlayerController(Pawn(Owner).Controller).ClientMessage("Exceeded error"@clErr);
    // Log(ClErr@(Pawn(Owner).Velocity dot Pawn(Owner).Velocity));
    // if(clErr >= 750) Log("ERROR TOO GREAT");
    return (LocDiff dot LocDiff) < 1250.0;
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
