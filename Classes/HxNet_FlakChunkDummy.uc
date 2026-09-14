class HxNet_FlakChunkDummy extends FlakChunk;

var HxNTWeaponInfo WeaponInfo;
var bool bRemoved;

simulated event Destroyed()
{
    if (!bRemoved && WeaponInfo != None)
    {
        WeaponInfo.RemoveProjectile(Self);
    }
    Super.Destroyed();
}

simulated function ProcessTouch(Actor Other, Vector HitLocation)
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
