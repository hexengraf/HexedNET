class NewNet_MiniGunFire extends MiniGunFire;

var private MutHexedNET HexedNET;
var private HxNTClient Client;

function PreBeginPlay()
{
    Super.PreBeginPlay();
    foreach Weapon.DynamicActors(class'MutHexedNET', HexedNET) break;
    class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client);
}

function bool IsEnhancedNetcodeEnabled()
{
    return class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        && Client.IsEnhancedNetcodeEnabled();
}

function DoTrace(vector Start, rotator Dir)
{
    if (Level.NetMode == NM_Client || !IsEnhancedNetcodeEnabled())
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
