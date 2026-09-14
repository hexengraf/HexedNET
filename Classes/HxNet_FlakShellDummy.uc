class HxNet_FlakShellDummy extends FlakShell;

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

simulated function Explode(Vector HitLocation, Vector HitNormal)
{
    Destroy();
}

defaultproperties
{
    bNetTemporary=false
}
