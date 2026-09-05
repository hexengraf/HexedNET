class NewNet_AssaultFire extends AssaultFire;

var private MutHexedNET HexedNET;
var private HxNTClient Client;

function PreBeginPlay()
{
    Super.PreBeginPlay();
    foreach Weapon.DynamicActors(class'MutHexedNET', HexedNET) break;
    class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client);
}

function bool WantsPingCompensation()
{
    return class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        && Client.WantsPingCompensation();
}

function DoTrace(vector Start, rotator Dir)
{
    if (Level.NetMode == NM_Client || !WantsPingCompensation())
    {
        super.DoTrace(Start, Dir);
    }
    else
    {
        class'HxNTWeapon'.static.InstantFireTrace(HexedNET, Self, Start, Dir, Client.AveragePing);
    }
}

DefaultProperties
{
}
