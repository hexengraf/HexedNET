class HxNet_LinkProjectileDummy extends LinkProjectile;

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
    bNetTemporary=false
}
