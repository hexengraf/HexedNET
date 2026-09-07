class HxNet_AssaultGrenade extends AssaultGrenade
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
    foreach Weapon.DynamicActors(class'MutHexedNET', HexedNET) break;
    class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client);
}

function bool WantsPingCompensation()
{
    return class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        && Client.WantsPingCompensation();
}

function ApplyBAS(HxNTWeapon.HxBAS BAS)
{
    class'HxNTWeapon'.static.DecodeBAS(BAS, BASStart, BASAim);
    bBoostedAimSynchronization = HexedNET == None || HexedNET.IsReasonable(Weapon, BASStart);
}

function GetProjectileStartAndDirection(out Vector Start, out Rotator Dir)
{
    local Vector HitLocation;
    local Vector HitNormal;
    local Vector X;
    local Vector Y;
    local Vector Z;

    if (bBoostedAimSynchronization)
    {
        bBoostedAimSynchronization = false;
        Dir = BASAim;
    }
    else
    {
        BASStart = Instigator.Location + Instigator.EyePosition();
        if (Instigator.Controller != None)
        {
            BASAim = Instigator.Controller.Rotation;
        }
        else
        {
            BASAim = Instigator.Rotation;
        }
        Dir = AdjustAim(Start, AimError);
    }
    GetAxes(BASAim, X, Y, Z);
    Start = BASStart + X * ProjSpawnOffset.X;
    if (AssaultRifle(Weapon).bDualMode)
    {
        AssaultRifle(Weapon).bFireLeft = !AssaultRifle(Weapon).bFireLeft;
        if (AssaultRifle(Weapon).bFireLeft)
        {
            Y *= -1;
        }
    }
    if (!Weapon.WeaponCentered())
    {
        Start = Start + Weapon.Hand * Y * ProjSpawnOffset.Y + Z * ProjSpawnOffset.Z;
    }
    if (Weapon.Trace(HitLocation, HitNormal, Start, BASStart, false) != None)
    {
        Start = HitLocation;
    }
}

// TODO: any sane way to show client-side immediate grenade? Randomized rotation inside Grenade
// causes trajectory changes, so client and server might _greatly_ differ.
function DoFireEffect()
{
    local Projectile P;
    local Vector Start;
    local Rotator Dir;

    Instigator.MakeNoise(1.0);
    GetProjectileStartAndDirection(Start, Dir);
    P = SpawnProjectile(Start, Dir);
    if (P != None && WantsPingCompensation())
    {
        HexedNET.ExtrapolateBouncingProjectile(Weapon, P, Client.GetProjectilePing() + ServerDelay);
    }
}

defaultproperties
{
}
