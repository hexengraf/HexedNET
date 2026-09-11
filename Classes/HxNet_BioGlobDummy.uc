class HxNet_BioGlobDummy extends BioGlob;

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
