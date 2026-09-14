class HxNet_BioGlobPredicted extends BioGlob;

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

function BlowUp(Vector HitLocation)
{
    Destroy();
}

singular function SplashGlobs(int NumGloblings)
{
}

defaultproperties
{
    bNetTemporary=false
}
