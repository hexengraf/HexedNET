class HxNet_BioGlobDummy extends BioGlob;

simulated function Destroyed()
{
    if (Fear != None)
    {
        Fear.Destroy();
    }
    if (Trail != None)
    {
        Trail.Destroy();
    }
    Super(Projectile).Destroyed();
}

singular function SplashGlobs(int NumGloblings)
{
}

defaultproperties
{
    bNetTemporary=false
}
