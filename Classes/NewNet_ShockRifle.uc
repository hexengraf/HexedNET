class NewNet_ShockRifle extends ShockRifle
    HideDropDown
    CacheExempt;

var private const class<Weapon> BaseClass;
var private bool bConfigCleared;

#include Classes\Include\WeaponBaseShockRifle.uci

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    if (Level.NetMode != NM_DedicatedServer)
    {
        ForceBaseClassConfig();
    }
}

simulated function DoInstantFireEffect(int Mode)
{
    NewNet_ShockBeamFire(FireMode[Mode]).DoInstantFireEffect(Mode);
}

function NewNet_ServerStartFire(byte Mode, float Ping, ReplicatedRotator R, ReplicatedVector V, bool bBelievesHit, Actor A/*, bool bBelievesHit, ReplicatedVector BelievedHLDelta, Actor A, vector HN, vector HL*/)
{
    if (!ServerShouldStartFire())
    {
        return;
    }
    ValidateNETClockPointer();
    NewNet_ShockBeamFire(FireMode[Mode]).PingDT = Ping;
    NewNet_ShockBeamFire(FireMode[Mode]).bUseEnhancedNetCode = true;

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
            NETClock.IsReasonable(Self, NewNet_ShockBeamFire(FireMode[Mode]).SavedVec);
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
    BaseClass=class'ShockRifle'
    FireModeClass(0)=class'NewNet_ShockBeamFire'
    FireModeClass(1)=class'NewNet_ShockProjFire'
}
