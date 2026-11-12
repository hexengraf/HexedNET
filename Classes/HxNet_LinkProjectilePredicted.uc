class HxNet_LinkProjectilePredicted extends LinkProjectile;

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
    bNetTemporary=false
}
