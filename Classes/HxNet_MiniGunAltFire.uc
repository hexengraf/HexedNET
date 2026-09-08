class HxNet_MiniGunAltFire extends MiniGunAltFire;

var private MutHexedNET HexedNET;
var private HxNTClient Client;

function PreBeginPlay()
{
    Super.PreBeginPlay();
    class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client);
}

function bool WantsPingCompensation()
{
    return class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        && Client.WantsPingCompensation();
}

function DoTrace(Vector Start, Rotator Dir)
{
    if (Level.NetMode == NM_Client || !WantsPingCompensation())
    {
        Super.DoTrace(Start, Dir);
    }
    else
    {
        class'HxNTWeapon'.static.InstantFireTrace(HexedNET, Self, Start, Dir, Client.AveragePing);
    }
}

defaultproperties
{
}
