class TimeStamp_Pawn extends Pawn;

var int Timestamp;
var float DT;

var private int Counter;

simulated event Tick(float DeltaTime)
{
   Super.Tick(DeltaTime);
   Counter = (Rotation.Yaw + Rotation.Pitch * 256) / 256;
   DT += DeltaTime;
   if (Counter > Timestamp || Timestamp - Counter > 5000)
   {
       Timestamp = Counter;
       DT = 0.00;
   }
}

// TODO: evaluate if it is worth using rotation (to use native replication)
// instead of declaring a replicated counter
function UpdateCounter(float NewCounter)
{
    local rotator R;

    R.Yaw = (NewCounter % 256) * 256;
    R.Pitch = int(NewCounter / 256) * 256;
    SetRotation(R);
}

// TODO: investigate how CounterPawn still ends up destroyed (couldn't reproduce locally).
// For now, let it self-destruct and we respawn it every round.
// function Reset()
// {
//     // skip Pawn.Reset() to prevent self-destroy
//     Super(Actor).Reset();
// }

DefaultProperties
{
    ControllerClass=None
    bAlwaysRelevant=true
    NetPriority=50
    bCollideActors=false
    bCollideWorld=false
    bBlockActors=false
    bProjTarget=false
    bCanBeDamaged=false
    bAcceptsProjectors=false
    bCanTeleport=false
    bBlockPlayers=false
    bDisturbFluidSurface=false
    Physics=Phys_None
    bStasis=false
    bHidden=true
}
