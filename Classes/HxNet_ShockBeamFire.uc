class HxNet_ShockBeamFire extends ShockBeamFire
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

function bool IsEnhancedNetcodeEnabled()
{
    return class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        && Client.IsEnhancedNetcodeEnabled();
}

function PlayFiring()
{
    Super.PlayFiring();
    if (Level.NetMode == NM_Client && IsEnhancedNetcodeEnabled()
        && Instigator.IsLocallyControlled())
    {
        DoFireEffect();
    }
}

function ApplyBAS(HxNTWeapon.HxBAS BAS)
{
    local Vector X;
    local Vector Y;
    local Vector Z;

    class'HxNTWeapon'.static.DecodeBAS(BAS, BASStart, BASAim);
    if (HexedNET == None || HexedNET.IsReasonable(Weapon, BASStart))
    {
        if (PlayerController(Instigator.Controller) != None)
        {
            GetAxes(BASAim, X, Y, Z);
            BASStart += X * class'ShockProjFire'.Default.ProjSpawnOffset.X;
            if (!Weapon.WeaponCentered())
            {
                BASStart += Weapon.Hand * Y * class'ShockProjFire'.Default.ProjSpawnOffset.Y
                    + Z * class'ShockProjFire'.Default.ProjSpawnOffset.Z;
            }
        }
        bBoostedAimSynchronization = true;
    }
}

function DoFireEffect()
{
    if (bBoostedAimSynchronization)
    {
        Instigator.MakeNoise(1.0);
        DoTrace(BASStart, BASAim);
        bBoostedAimSynchronization = false;
    }
    else
    {
        Super.DoFireEffect();
    }
    ServerDelay = 0;
}

function SpawnBeamEffect(Vector Start,
                         Rotator Dir,
                         Vector HitLocation,
                         Vector HitNormal,
                         int ReflectNum)
{
    if (Level.NetMode != NM_Client && ReflectNum == 0)
    {
        BeamEffectClass = class'HxNet_ShockBeamEffect';
        Super.SpawnBeamEffect(Start, Dir, HitLocation, HitNormal, ReflectNum);
        BeamEffectClass = default.BeamEffectClass;
    }
    else
    {
        Super.SpawnBeamEffect(Start, Dir, HitLocation, HitNormal, ReflectNum);
    }
}

function DoTrace(Vector Start, Rotator Dir)
{
    if (IsEnhancedNetcodeEnabled())
    {
        class'HxNTWeapon'.static.InstantFireTrace(
            HexedNET, Self, Start, Dir, Client.AveragePing + ServerDelay);
    }
    else
    {
        Super.DoTrace(Start, Dir);
    }
}

DefaultProperties
{
}
