class HxNet_ZoomSuperShockBeamFire extends ZoomSuperShockBeamFire
    DependsOn(HxNTWeapon);

var bool bServerAllowMultiHit;
var float ServerDelay;
var private MutHexedNET HexedNET;
var private HxNTClient Client;
var private vector BASStart;
var private rotator BASAim;
var private bool bBoostedAimSynchronization;

function PreBeginPlay()
{
    Super.PreBeginPlay();
    foreach Weapon.DynamicActors(class'MutHexedNET', HexedNET) break;
    class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client);
    if (bAllowMultiHit != class'ZoomSuperShockBeamFire'.default.bAllowMultiHit)
    {
        ClearConfig();
        default.bAllowMultiHit = class'ZoomSuperShockBeamFire'.default.bAllowMultiHit;
        bAllowMultiHit = default.bAllowMultiHit;
    }
}

function bool WantsPingCompensation()
{
    return class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        && Client.WantsPingCompensation();
}

function PlayFiring()
{
    Super.PlayFiring();
    if (Level.NetMode == NM_Client && WantsPingCompensation() && Instigator.IsLocallyControlled())
    {
        DoFireEffect();
    }
}

function ApplyBAS(HxNTWeapon.HxBAS BAS)
{
    class'HxNTWeapon'.static.DecodeBAS(BAS, BASStart, BASAim);
    bBoostedAimSynchronization = HexedNET == None || HexedNET.IsReasonable(Weapon, BASStart);
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

function SpawnBeamEffect(vector Start,
                         rotator Dir,
                         vector HitLocation,
                         vector HitNormal,
                         int ReflectNum)
{
    local ShockBeamEffect Beam;

    if (Level.NetMode != NM_Client && WantsPingCompensation())
    {
        if (Weapon != None)
        {
            if (Instigator.PlayerReplicationInfo.Team != None
                && Instigator.PlayerReplicationInfo.Team.TeamIndex == 1)
            {
                Beam = Weapon.Spawn(class'HxNet_BlueSuperShockBeam', Weapon.Owner,, Start, Dir);
            }
            else
            {
                Beam = Weapon.Spawn(class'HxNet_SuperShockBeamEffect', Weapon.Owner,, Start, Dir);
            }
            if (ReflectNum != 0)
            {
                Beam.Instigator = None;
            }
            Beam.AimAt(HitLocation, HitNormal);
        }
    }
    else
    {
        Super.SpawnBeamEffect(Start, Dir, HitLocation, HitNormal, ReflectNum);
    }
}

function TracePart(Vector Start, Vector End, Vector X, Rotator Dir, Pawn Ignored)
{
    if (!WantsPingCompensation())
    {
        Super.TracePart(Start, End, X, Dir, Ignored);
    }
    else if (HexedNET != None)
    {
        HexedNET.Rewind(Client.AveragePing + ServerDelay);
        class'HxNet_SuperShockBeamFire'.static.StaticTracePart(
            HexedNET, Self, Start, End, X, Dir, Ignored);
        HexedNET.UndoRewind();
    }
    else
    {
        class'HxNet_SuperShockBeamFire'.static.StaticTracePart(
            HexedNET, Self, Start, End, X, Dir, Ignored);
    }
}

function bool AllowMultiHit()
{
    if (Level.NetMode == NM_Client)
    {
        return default.bServerAllowMultiHit;
    }
    return bAllowMultiHit;
}
