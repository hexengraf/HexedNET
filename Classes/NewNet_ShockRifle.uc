class NewNet_ShockRifle extends ShockRifle
    HideDropDown
    CacheExempt;

var private MutHexedNET HexedNET;
var private HxNTClient Client;
var private bool bConfigCleared;

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
        class'HxNTWeapon'.static.ForceBaseClassConfig(Self, class'ShockRifle');
    }
}

simulated function PostBeginPlay()
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
    local NewNet_ShockBeamFire ShockBeamFire;
    local ReplicatedRotator R;
    local ReplicatedVector V;
    local vector Start;
    local Actor A;
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
            ShockBeamFire = NewNet_ShockBeamFire(FireMode[Mode]);
            ShockBeamFire.SavedVec.X = V.X;
            ShockBeamFire.SavedVec.Y = V.Y;
            ShockBeamFire.SavedVec.Z = V.Z;
            ShockBeamFire.SavedRot.Yaw = R.Yaw;
            ShockBeamFire.SavedRot.Pitch = R.Pitch;
            ShockBeamFire.bUseReplicatedInfo = true;
            ShockBeamFire.EnqueueStopFire(Mode);
            A = Trace(
                HN, HL, Start + Vector(Pawn(Owner).Controller.Rotation) * 40000.0, Start, true);
            NewNet_ServerStartFire(
                Mode, R, V, A != None && (A.IsA('xPawn') || A.IsA('Vehicle')), A);
        }
    }
    else
    {
        StartFire(Mode);
    }
}

function NewNet_ServerStartFire(byte Mode, ReplicatedRotator R, ReplicatedVector V, bool bBelievesHit, Actor A)
{
    local NewNet_ShockBeamFire ShockBeamFire;

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
    ShockBeamFire = NewNet_ShockBeamFire(FireMode[Mode]);
    if (bBelievesHit)
    {
        ShockBeamFire.BelievedHitActor = A;
    }
    ShockBeamFire.bBelievesHit = bBelievesHit;
    ShockBeamFire.bFirstGo = true;
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
    FireModeClass(0)=class'NewNet_ShockBeamFire'
    FireModeClass(1)=class'NewNet_ShockProjFire'
}
