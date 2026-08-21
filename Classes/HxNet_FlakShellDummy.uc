class HxNet_FlakShellDummy extends FlakShell;

simulated function Explode(vector HitLocation, vector HitNormal)
{
    Destroy();
}

defaultproperties
{
    bNetTemporary=false
}
