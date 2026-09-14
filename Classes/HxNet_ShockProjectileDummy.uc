class HxNet_ShockProjectileDummy extends ShockProjectile;

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

defaultproperties
{
    bCollideActors=false
}
