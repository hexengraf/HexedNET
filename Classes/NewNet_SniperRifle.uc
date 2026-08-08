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
var float lastDT;

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
    local ReplicatedRotator R;
    local ReplicatedVector V;
    local vector Start;
    local Actor A;
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
        if (ReadyToFire(Mode) && StartFire(Mode) )
        {
            R.Pitch = Pawn(Owner).Controller.Rotation.Pitch;
            R.Yaw = Pawn(Owner).Controller.Rotation.Yaw;
            Start = Pawn(Owner).Location + Pawn(Owner).EyePosition();
            V.X = Start.X;
            V.Y = Start.Y;
            V.Z = Start.Z;
            NewNet_SniperFire(FireMode[Mode]).DoInstantFireEffect();
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

function bool ServerShouldStartFire()
{
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
        return false;
    }
    return true;
}

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
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

simulated function SpawnLGEffect(class<Actor> tmpHitEmitClass, vector ArcEnd, vector HitNormal, vector HitLocation)
{
    local xEmitter HitEmitter;
    hitEmitter = xEmitter(Spawn(tmpHitEmitClass,,, arcEnd, Rotator(HitNormal)));
    if ( hitEmitter != None )
	  	hitEmitter.mSpawnVecA = HitLocation;
    if(Level.NetMode!=NM_Client)
        Warn("Server should never spawn the client lightningbolt");
}

function NewNet_ServerStartFire(byte Mode, ReplicatedRotator R, ReplicatedVector V, bool bBelievesHit, optional actor A)
{
    if (!ServerShouldStartFire())
    {
        return;
    }
    if(bBelievesHit)
    {
        newNet_sniperFire(FireMode[Mode]).bBelievesHit=true;
        newNet_SniperFire(FireMode[Mode]).BelievedHitActor=A;
    }
    else
    {
        newNet_sniperFire(FireMode[Mode]).bBelievesHit=false;
    }
    NewNet_SniperFire(FireMode[Mode]).bFirstGo = true;
    if ( (FireMode[Mode].NextFireTime <= Level.TimeSeconds + FireMode[Mode].PreFireTime)
		&& StartFire(Mode) )
    {
        FireMode[Mode].ServerStartFireTime = Level.TimeSeconds;
        FireMode[Mode].bServerDelayStartFire = false;
        NewNet_SniperFire(FireMode[Mode]).SavedVec.X = V.X;
        NewNet_SniperFire(FireMode[Mode]).SavedVec.Y = V.Y;
        NewNet_SniperFire(FireMode[Mode]).SavedVec.Z = V.Z;
        NewNet_SniperFire(FireMode[Mode]).SavedRot.Yaw = R.Yaw;
        NewNet_SniperFire(FireMode[Mode]).SavedRot.Pitch = R.Pitch;
        NewNet_SniperFire(FireMode[Mode]).bUseReplicatedInfo =
            HexedNET.IsReasonable(Self, NewNet_SniperFire(FireMode[Mode]).SavedVec);
   //     NewNet_SniperFire(FireMode[Mode]).bBelievesHit=bBelievesHit;
   //     NewNet_SniperFire(FireMode[Mode]).bCount=true;
   /*     NewNet_SniperFire(FireMode[Mode]).BelievedHLDelta.X = BelievedHLDelta.X;
        NewNet_SniperFire(FireMode[Mode]).BelievedHLDelta.Y = BelievedHLDelta.Y;
        NewNet_SniperFire(FireMode[Mode]).BelievedHLDelta.Z = BelievedHLDelta.Z;
        NewNet_SniperFire(FireMode[Mode]).SavedVec = Pawn(Owner).Location;
        NewNet_SniperFire(FireMode[Mode]).SavedRot = Pawn(Owner).Controller.Rotation;
    */
    }
    else if ( FireMode[Mode].AllowFire() )
    {
        FireMode[Mode].bServerDelayStartFire = true;
	}
	else
		ClientForceAmmoUpdate(Mode, AmmoAmount(Mode));
}

simulated function Weapontick(float deltatime)
{
   lastDT = deltatime;
}

//// client & server ////
simulated function bool StartFire(int Mode)
{
    local int alt;

    if (!ReadyToFire(Mode))
        return false;

    if (Mode == 0)
        alt = 1;
    else
        alt = 0;

    FireMode[Mode].bIsFiring = true;

    FireMode[Mode].NextFireTime = Level.TimeSeconds-LastDT*0.5 + FireMode[Mode].PreFireTime;

    if (FireMode[alt].bModeExclusive)
    {
        // prevents rapidly alternating fire modes
        FireMode[Mode].NextFireTime = FMax(FireMode[Mode].NextFireTime, FireMode[alt].NextFireTime);
    }

    if (Instigator.IsLocallyControlled())
    {
        if (FireMode[Mode].PreFireTime > 0.0 || FireMode[Mode].bFireOnRelease)
        {
            FireMode[Mode].PlayPreFire();
        }
        FireMode[Mode].FireCount = 0;
    }

    return true;
}

defaultproperties
{
    FireModeClass(0) = class'NewNet_SniperFire'
}
