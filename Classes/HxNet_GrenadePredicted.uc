class HxNet_GrenadePredicted extends HxNet_Grenade;

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
    Super(Grenade).Explode(HitLocation, HitNormal);
}

simulated function BlowUp(Vector HitLocation)
{
}

defaultproperties
{
    bNetTemporary=false
}
