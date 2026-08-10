class NewNet_SniperRifle extends SniperRifle
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

replication
{
    reliable if(Role < Role_Authority)
        NewNet_ServerStartFire;
    unreliable if(bDemoRecording)
        SpawnLGEffect;
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
        class'HxNTWeapon'.static.ForceBaseClassConfig(Self, class'SniperRifle');
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
    local NewNet_SniperFire SniperFire;
    local ReplicatedRotator R;
    local ReplicatedVector V;
    local vector Start;
    local Actor Injured;
    local vector HN;
    local vector HL;

    if (Level.NetMode != NM_Client
        || Mode == 1
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
            SniperFire = NewNet_SniperFire(FireMode[Mode]);
            SniperFire.SavedVec.X = V.X;
            SniperFire.SavedVec.Y = V.Y;
            SniperFire.SavedVec.Z = V.Z;
            SniperFire.SavedRot.Yaw = R.Yaw;
            SniperFire.SavedRot.Pitch = R.Pitch;
            SniperFire.bUseReplicatedInfo = true;
            SniperFire.EnqueueStopFire();
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

simulated function SpawnLGEffect(class<Actor> tmpHitEmitClass, vector ArcEnd, vector HitNormal, vector HitLocation)
{
    local xEmitter HitEmitter;
    hitEmitter = xEmitter(Spawn(tmpHitEmitClass,,, arcEnd, Rotator(HitNormal)));
    if ( hitEmitter != None )
	  	hitEmitter.mSpawnVecA = HitLocation;
    if(Level.NetMode!=NM_Client)
        Warn("Server should never spawn the client lightningbolt");
}

function NewNet_ServerStartFire(byte Mode, ReplicatedRotator R, ReplicatedVector V, Actor Injured)
{
    local NewNet_SniperFire SniperFire;

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
    SniperFire = NewNet_SniperFire(FireMode[Mode]);
    SniperFire.Injured = Injured;
    SniperFire.bFirstGo = true;
    SniperFire.SavedVec.X = V.X;
    SniperFire.SavedVec.Y = V.Y;
    SniperFire.SavedVec.Z = V.Z;
    SniperFire.SavedRot.Yaw = R.Yaw;
    SniperFire.SavedRot.Pitch = R.Pitch;
    SniperFire.bUseReplicatedInfo = HexedNET.IsReasonable(Self, SniperFire.SavedVec);
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

defaultproperties
{
    FireModeClass(0) = class'NewNet_SniperFire'
}
