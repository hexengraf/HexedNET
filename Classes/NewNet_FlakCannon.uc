class NewNet_FlakCannon extends FlakCannon
    HideDropDown
	CacheExempt;

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

var private MutHexedNET HexedNET;
var private HxNTClient Client;
var private bool bConfigCleared;

var rotator RandSeed[9];
var int RandIndex;
var float lastDT;

replication
{
    reliable if(Role < Role_Authority)
        NewNet_ServerStartFire;
    unreliable if(Role == Role_Authority && bNetOwner)
        RandSeed;
}

simulated event PreBeginPlay()
{
    Super.PreBeginPlay();
    if (Level.NetMode != NM_DedicatedServer)
    {
        if (!default.bConfigCleared)
        {
            ClearConfig();
            default.bConfigCleared = true;
        }
        class'HxNTWeapon'.static.ForceBaseClassConfig(Self, class'FlakCannon');
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
    local NewNet_FlakFire FlakFire;
    local NewNet_FlakAltFire FlakAltFire;
    local ReplicatedRotator R;
    local ReplicatedVector V;
    local vector Start;

    if (Level.NetMode != NM_Client
        || !IsEnhancedNetcodeEnabled()
        || Pawn(Owner).Controller.IsInState('GameEnded')
        || Pawn(Owner).Controller.IsInState('RoundEnded'))
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
            FlakFire = NewNet_FlakFire(FireMode[Mode]);
            FlakAltFire = NewNet_FlakAltFire(FireMode[Mode]);
            if (FlakFire != None)
            {
                FlakFire.SavedVec.X = V.X;
                FlakFire.SavedVec.Y = V.Y;
                FlakFire.SavedVec.Z = V.Z;
                FlakFire.SavedRot.Yaw = R.Yaw;
                FlakFire.SavedRot.Pitch = R.Pitch;
                FlakFire.EnqueueStopFire();
            }
            else if (FlakAltFire != None)
            {
                FlakAltFire.SavedVec.X = V.X;
                FlakAltFire.SavedVec.Y = V.Y;
                FlakAltFire.SavedVec.Z = V.Z;
                FlakAltFire.SavedRot.Yaw = R.Yaw;
                FlakAltFire.SavedRot.Pitch = R.Pitch;
                FlakAltFire.EnqueueStopFire();
            }
            NewNet_ServerStartFire(mode, R, V);
        }
    }
    else
    {
        StartFire(Mode);
    }
}

function NewNet_ServerStartFire(byte Mode, ReplicatedRotator R, ReplicatedVector V)
{
    local NewNet_FlakFire FlakFire;
    local NewNet_FlakAltFire FlakAltFire;

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
    FlakFire = NewNet_FlakFire(FireMode[Mode]);
    FlakAltFire = NewNet_FlakAltFire(FireMode[Mode]);
    if (FlakFire != None)
    {
        FlakFire.SavedVec.X = V.X;
        FlakFire.SavedVec.Y = V.Y;
        FlakFire.SavedVec.Z = V.Z;
        FlakFire.SavedRot.Yaw = R.Yaw;
        FlakFire.SavedRot.Pitch = R.Pitch;
        FlakFire.bUseReplicatedInfo = HexedNET.IsReasonable(Self, FlakFire.SavedVec);
    }
    else if (FlakAltFire != None)
    {
        FlakAltFire.SavedVec.X = V.X;
        FlakAltFire.SavedVec.Y = V.Y;
        FlakAltFire.SavedVec.Z = V.Z;
        FlakAltFire.SavedRot.Yaw = R.Yaw;
        FlakAltFire.SavedRot.Pitch = R.Pitch;
        FlakAltFire.bUseReplicatedInfo = HexedNET.IsReasonable(Self, FlakAltFire.SavedVec);
    }
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

function SendNewRandSeed()
{
    local rotator R;
    local int i;
    local float Spread;
    Spread = class'NewNet_FlakFire'.default.Spread;
    for(i=0; i<ArrayCount(RandSeed); i++)
    {
        R.Yaw = Spread * (FRand()-0.5);
        R.Pitch = Spread * (FRand()-0.5);
        R.Roll = Spread * (FRand()-0.5);

        RandSeed[i]=R;
    }
    RandIndex=0;
}

simulated function rotator GetRandRot()
{
    if(RandIndex > 8)
    {
        RandIndex = 0;
    }
    RandIndex++;
    return RandSeed[RandIndex-1];
}

simulated event PostNetBeginPlay()
{
    super.PostNetBeginPlay();
    SendNewRandSeed();
}

defaultproperties
{
    FireModeClass(0)=class'NewNet_FlakFire'
    FireModeClass(1)=class'NewNet_FlakAltFire'
}
