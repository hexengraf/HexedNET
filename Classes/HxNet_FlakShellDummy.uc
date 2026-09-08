class HxNet_FlakShellDummy extends FlakShell;

simulated function Explode(Vector HitLocation, Vector HitNormal)
{
    Destroy();
}

defaultproperties
{
    bNetTemporary=false
}
