class HxNTClock extends Actor;

const AVERDT_SEND_PERIOD = 4.00;

var float ServerAverDT;

var float DT;
var float AverDT;
var int ClientCounter;

var private int ServerCounter;
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
    if (ServerCounter > ClientCounter || ClientCounter - ServerCounter > 5000)
    {
        ClientCounter = ServerCounter;
        DT = 0.00;
    }
    default.AverDT = AverDT;
}

function Update(float DeltaTime)
{
    ServerAverDT = (9.0 * ServerAverDT + DeltaTime) * 0.1;
    if (Level.TimeSeconds > LastReplicatedAverDT + AVERDT_SEND_PERIOD)
    {
        AverDT = ServerAverDT;
        LastReplicatedAverDT = Level.TimeSeconds;
    }
    ++ServerCounter;
    Timestamps[ServerCounter % 256] = Level.TimeSeconds;
}

function float GetPingDT(byte ClientCounter, float DT)
{
    return Level.TimeSeconds - Timestamps[ClientCounter] - DT + (0.5 * ServerAverDT);
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
