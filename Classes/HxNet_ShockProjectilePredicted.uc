class HxNet_ShockProjectilePredicted extends ShockProjectile;

var HxNTWeaponInfo WeaponInfo;
var bool bRemoved;

simulated event Destroyed()
{
    if (!bRemoved && WeaponInfo != None)
    {
        WeaponInfo.RemovePredictedProjectile(Self);
    }
    Super.Destroyed();
}

defaultproperties
{
    bCollideActors=false
}
