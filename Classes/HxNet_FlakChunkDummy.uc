class HxNet_FlakChunkDummy extends FlakChunk;

var int Index;

function Randomize(Rotator NewRotation, int NewIndex, int NewBounces)
{
    Index = NewIndex;
    Bounces = NewBounces;
    SetRotation(NewRotation);
}

simulated function ProcessTouch(Actor Other, vector HitLocation)
{
    if (FlakChunk(Other) == None && (Physics == PHYS_Falling || Other != Instigator))
    {
        Speed = VSize(Velocity);
        if (Speed > 200 && Role == ROLE_Authority
            && (Instigator == None || Instigator.Controller == None))
        {
            Other.SetDelayedDamageInstigatorController(InstigatorController);
        }
        Destroy();
    }
}

defaultproperties
{
    bNetTemporary=false
}
