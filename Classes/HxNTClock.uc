class HxNTClock extends Actor;

var float AverDT;

replication
{
    unreliable if (Role == Role_Authority)
        AverDT;
}

simulated function PostBeginPlay()
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

function bool IsReasonable(Weapon W, Vector V)
{
    local vector LocDiff;

    if (Pawn(W.Owner) == None)
    {
        return true;
    }
    LocDiff = V - (Pawn(W.Owner).Location + Pawn(W.Owner).EyePosition());
    // clErr = (LocDiff dot LocDiff);
    // if (clErr > 500.0*NETClock.AverDT)
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
    NetUpdateFrequency=0.25
    NetPriority=3
    bHidden=true
}
