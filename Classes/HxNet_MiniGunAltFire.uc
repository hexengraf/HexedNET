class HxNet_MiniGunAltFire extends MiniGunAltFire;

var private MutHexedNET HexedNET;
var private HxNTClient Client;

function PreBeginPlay()
{
    Super.PreBeginPlay();
    class'HxNTWeapon'.static.ValidateClient(Level, Instigator, Client, HexedNET);
}

function bool WantsLagCompensation()
{
    return class'HxNTWeapon'.static.ValidateClient(Level, Instigator, Client, HexedNET)
        && Client.WantsLagCompensation();
}

function DoTrace(Vector Start, Rotator Dir)
{
    if (Level.NetMode == NM_Client || !WantsLagCompensation())
    {
        Super.DoTrace(Start, Dir);
    }
    else
    {
        class'HxNTWeapon'.static.InstantFireTrace(
            HexedNET, Self, Start, Dir, Client.GetCompensationTime());
    }
}

defaultproperties
{
}
