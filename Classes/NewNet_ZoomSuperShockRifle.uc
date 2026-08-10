class NewNet_ZoomSuperShockRifle extends ZoomSuperShockRifle
    HideDropDown
    CacheExempt;

var private bool bConfigCleared;

var private MutHexedNET HexedNET;
var private HxNTClient Client;
var float LastDT;

struct ReplicatedRotator
{
    var int Yaw;
    var int Pitch;
};

struct ReplicatedVector
{
    var float X;
    var float Y;
    var float Z;
};

replication
{
    reliable if (Role < ROLE_Authority)
        NewNet_ServerStartFire;
}

simulated function PreBeginPlay()
{
    Super.PreBeginPlay();
    if (Level.NetMode != NM_DedicatedServer)
    {
        if (!default.bConfigCleared)
        {
            ClearConfig();
            default.bConfigCleared = true;
        }
        class'HxNTWeapon'.static.ForceBaseClassConfig(Self, class'ZoomSuperShockRifle');
    }
}

simulated event PostBeginPlay()
{
    Super.PostBeginPlay();
    if (Level.NetMode != NM_Client)
    {
        foreach DynamicActors(class'MutHexedNET', HexedNET) break;
    }
    class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client);
}

simulated function bool IsEnhancedNetcodeEnabled()
{
    return class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        && Client.IsEnhancedNetcodeEnabled();
}

simulated event ClientStartFire(int Mode)
{
    local NewNet_ZoomSuperShockBeamFire ShockBeamFire;
    local ReplicatedRotator R;
    local ReplicatedVector V;
    local vector Start;
    local Actor Injured;
    local vector HN;
    local vector HL;

    if (Level.NetMode != NM_Client
        || ShockBeamFire(FireMode[Mode]) == None
        || Pawn(Owner).Controller.IsInState('GameEnded')
        || Pawn(Owner).Controller.IsInState('RoundEnded')
        || !IsEnhancedNetcodeEnabled())
    {
        Super.ClientStartFire(Mode);
    }
    else if (Role < ROLE_Authority)
    {
        if (StartFire(Mode))
        {
            R.Pitch = Pawn(Owner).Controller.Rotation.Pitch;
            R.Yaw = Pawn(Owner).Controller.Rotation.Yaw;
            Start = Pawn(Owner).Location + Pawn(Owner).EyePosition();
            V.X = Start.X;
            V.Y = Start.Y;
            V.Z = Start.Z;
            ShockBeamFire = NewNet_ZoomSuperShockBeamFire(FireMode[Mode]);
            ShockBeamFire.SavedVec.X = V.X;
            ShockBeamFire.SavedVec.Y = V.Y;
            ShockBeamFire.SavedVec.Z = V.Z;
            ShockBeamFire.SavedRot.Yaw = R.Yaw;
            ShockBeamFire.SavedRot.Pitch = R.Pitch;
            ShockBeamFire.bUseReplicatedInfo = true;
            ShockBeamFire.EnqueueStopFire(Mode);
            Injured = Trace(
                HN, HL, Start + Vector(Pawn(Owner).Controller.Rotation) * 40000.0, Start, true);
            if (Injured != None && !Injured.IsA('xPawn') && !Injured.IsA('Vehicle'))
            {
                Injured = None;
            }
            NewNet_ServerStartFire(Mode, R, V, Injured);
        }
    }
    else
    {
        StartFire(Mode);
    }
}

function NewNet_ServerStartFire(byte Mode, ReplicatedRotator R, ReplicatedVector V, Actor Injured)
{
    local NewNet_ZoomSuperShockBeamFire ShockBeamFire;

    if (Instigator != None && Instigator.Weapon != Self)
    {
        if (Instigator.Weapon == None)
        {
            Instigator.ServerChangedWeapon(None, Self);
        }
        else
        {
            Instigator.Weapon.SynchronizeWeapon(Self);
        }
        return;
    }
    ShockBeamFire = NewNet_ZoomSuperShockBeamFire(FireMode[Mode]);
    ShockBeamFire.Injured = Injured;
    ShockBeamFire.FirstGo = 1;
    ShockBeamFire.SavedVec.X = V.X;
    ShockBeamFire.SavedVec.Y = V.Y;
    ShockBeamFire.SavedVec.Z = V.Z;
    ShockBeamFire.SavedRot.Yaw = R.Yaw;
    ShockBeamFire.SavedRot.Pitch = R.Pitch;
    ShockBeamFire.bUseReplicatedInfo = HexedNET.IsReasonable(Self, ShockBeamFire.SavedVec);
    if (FireMode[Mode].NextFireTime <= Level.TimeSeconds + FireMode[Mode].PreFireTime
        && StartFire(Mode))
    {
        FireMode[Mode].ServerStartFireTime = Level.TimeSeconds;
        FireMode[Mode].bServerDelayStartFire = false;
    }
    else if (FireMode[Mode].AllowFire())
    {
        FireMode[Mode].bServerDelayStartFire = true;
    }
    else
    {
        ClientForceAmmoUpdate(Mode, AmmoAmount(Mode));
    }
}

DefaultProperties
{
    FireModeClass(0)=class'NewNet_ZoomSuperShockBeamFire'
}
