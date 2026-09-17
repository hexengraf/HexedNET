class HxNet_AssaultFire extends AssaultFire
    DependsOn(HxNTWeapon);

var float ServerDelay;
var private MutHexedNET HexedNET;
var private HxNTClient Client;
var private Vector BASStart;
var private Rotator BASAim;
var private bool bBoostedAimSynchronization;

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

function ApplyBAS(HxNTWeapon.HxBAS BAS)
{
    if (class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client))
    {
        class'HxNTWeapon'.static.DecodeBAS(BAS, BASStart, BASAim);
        bBoostedAimSynchronization = Client.IsAcceptableBAS(Weapon, BASStart, BASAim);
    }
}

function PlayFiring()
{
    Super.PlayFiring();
    if (Level.NetMode == NM_Client && WantsPingCompensation() && Instigator.IsLocallyControlled())
    {
        DoFireEffect();
    }
}

function DoFireEffect()
{
    if (bBoostedAimSynchronization)
    {
        Instigator.MakeNoise(1.0);
        DoTrace(BASStart, Rotator(Vector(BASAim) + VRand() * FRand() * Spread));
        bBoostedAimSynchronization = false;
    }
    else
    {
        Super.DoFireEffect();
    }
    ServerDelay = 0;
}

function DoTrace(Vector Start, Rotator Dir)
{
    if (Level.NetMode == NM_Client || !WantsPingCompensation())
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
