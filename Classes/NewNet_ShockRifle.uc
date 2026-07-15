class NewNet_ShockRifle extends ShockRifle
    HideDropDown
    CacheExempt;

var private MutHexedNET HexedNET;
var private HxNTClient Client;
var private bool bConfigCleared;
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

simulated event PreBeginPlay()
{
    Super.PreBeginPlay();
    if (Level.NetMode != NM_Client)
    {
        foreach DynamicActors(class'MutHexedNET', HexedNET) break;
    }
    class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client);
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
        class'HxNTWeapon'.static.ForceBaseClassConfig(Self, class'ShockRifle');
    }
}

simulated function bool IsEnhancedNetcodeEnabled()
{
    return class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        && Client.IsEnhancedNetcodeEnabled();
}

simulated event ClientStartFire(int Mode)
{
    if (Level.NetMode != NM_Client
        || !IsEnhancedNetcodeEnabled()
        || Pawn(Owner).Controller.IsInState('GameEnded')
        || Pawn(Owner).Controller.IsInState('RoundEnded'))
    {
        Super.ClientStartFire(Mode);
    }
    else
    {
        NewNet_ClientStartFire(Mode);
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

simulated event NewNet_ClientStartFire(int Mode)
{
    local ReplicatedRotator R;
    local ReplicatedVector V;
    local vector Start;
    local bool b;
    local actor A;
    local vector HN,HL;

    if (ShockBeamFire(FireMode[Mode]) == None
        || !class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client))
    {
        Super.ClientStartFire(Mode);
    }
    else if (Role < ROLE_Authority)
    {
        if (ReadyToFire(Mode) && StartFire(Mode))
        {
            R.Pitch = Pawn(Owner).Controller.Rotation.Pitch;
            R.Yaw = Pawn(Owner).Controller.Rotation.Yaw;
            STart = Pawn(Owner).Location + Pawn(Owner).EyePosition();
            V.X = Start.X;
            V.Y = Start.Y;
            V.Z = Start.Z;
            DoInstantFireEffect(Mode);
            A = Trace(
                HN, HL, Start + Vector(Pawn(Owner).Controller.Rotation) * 40000.0, Start, true);
            if (A != None && (A.IsA('xPawn') || A.IsA('Vehicle')))
            {
                b = true;
            }
            NewNet_ServerStartFire(Mode, R, V, b, A);
        }
    }
    else
    {
        StartFire(Mode);
    }
}

simulated function WeaponTick(float DeltaTime)
{
   lastDT = DeltaTime;
   Super.WeaponTick(DeltaTime);
}

//// client & server ////
simulated function bool StartFire(int Mode)
{
    local int Alt;

    if (bWaitForCombo && Bot(Instigator.Controller) != None)
    {
        if (ComboTarget != None && !ComboTarget.bDeleteMe)
        {
            return false;
        }
        bWaitForCombo = false;
    }
    if (!ReadyToFire(Mode))
    {
        return false;
    }
    Alt = 1 - Mode;
    FireMode[Mode].bIsFiring = true;
    FireMode[Mode].NextFireTime = Level.TimeSeconds - LastDT * 0.5 + FireMode[Mode].PreFireTime;
    if (FireMode[Alt].bModeExclusive)
    {
        // prevents rapidly alternating fire modes
        FireMode[Mode].NextFireTime = FMax(FireMode[Mode].NextFireTime, FireMode[Alt].NextFireTime);
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

simulated function DoInstantFireEffect(int Mode)
{
    NewNet_ShockBeamFire(FireMode[Mode]).DoInstantFireEffect(Mode);
}

function NewNet_ServerStartFire(byte Mode, ReplicatedRotator R, ReplicatedVector V, bool bBelievesHit, Actor A/*, bool bBelievesHit, ReplicatedVector BelievedHLDelta, Actor A, vector HN, vector HL*/)
{
    if (!ServerShouldStartFire())
    {
        return;
    }
    if (bBelievesHit)
    {
        NewNet_ShockBeamFire(FireMode[Mode]).BelievedHitActor = A;
    }
    NewNet_ShockBeamFire(FireMode[Mode]).bBelievesHit = bBelievesHit;
    NewNet_ShockBeamFire(FireMode[Mode]).bFirstGo = true;
    if (FireMode[Mode].NextFireTime <= Level.TimeSeconds + FireMode[Mode].PreFireTime
        && StartFire(Mode))
    {
        FireMode[Mode].ServerStartFireTime = Level.TimeSeconds;
        FireMode[Mode].bServerDelayStartFire = false;
        NewNet_ShockBeamFire(FireMode[Mode]).SavedVec.X = V.X;
        NewNet_ShockBeamFire(FireMode[Mode]).SavedVec.Y = V.Y;
        NewNet_ShockBeamFire(FireMode[Mode]).SavedVec.Z = V.Z;
        NewNet_ShockBeamFire(FireMode[Mode]).SavedRot.Yaw = R.Yaw;
        NewNet_ShockBeamFire(FireMode[Mode]).SavedRot.Pitch = R.Pitch;
        NewNet_ShockBeamFire(FireMode[Mode]).bUseReplicatedInfo =
            HexedNET.IsReasonable(Self, NewNet_ShockBeamFire(FireMode[Mode]).SavedVec);
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

simulated function bool ReadyToFire(int Mode)
{
    if (Level.NetMode == NM_Client && IsEnhancedNetcodeEnabled())
    {
        if (FireMode[Mode].bModeExclusive)
        {
            FireMode[Mode].NextFireTime = FMax(
                FireMode[Mode].NextFireTime, FireMode[1 - Mode].NextFireTime);
        }
    }
	return Super.ReadyToFire(Mode);
}

DefaultProperties
{
    FireModeClass(0)=class'NewNet_ShockBeamFire'
    FireModeClass(1)=class'NewNet_ShockProjFire'
}
