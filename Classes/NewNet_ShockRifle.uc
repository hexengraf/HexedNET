class NewNet_ShockRifle extends ShockRifle
    HideDropDown
    CacheExempt;

#include Classes\Include\WeaponBaseShockRifle.uci

simulated function DoInstantFireEffect(int Mode)
{
    NewNet_ShockBeamFire(FireMode[Mode]).DoInstantFireEffect();
}

function NewNet_ServerStartFire(byte Mode, byte ClientCounter, float DT, ReplicatedRotator R, ReplicatedVector V, bool bBelievesHit, Actor A/*, bool bBelievesHit, ReplicatedVector BelievedHLDelta, Actor A, vector HN, vector HL*/)
{
    if (!ServerShouldStartFire())
    {
        return;
    }
    ValidateNETClockPointer();
    NewNet_ShockBeamFire(FireMode[Mode]).PingDT = NETClock.GetPingDT(ClientCounter, DT);
    NewNet_ShockBeamFire(FireMode[Mode]).bUseEnhancedNetCode = true;
    NewNet_ShockBeamFire(FireMode[Mode]).AverDT = NETClock.ServerAverDT;

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
            IsReasonable(NewNet_ShockBeamFire(FireMode[Mode]).SavedVec);
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

function NewNet_OldServerStartFire(byte Mode, byte ClientCounter, float dt)
{
    ValidateNETClockPointer();
    NewNet_ShockBeamFire(FireMode[Mode]).PingDT = NETClock.GetPingDT(ClientCounter, DT);
    NewNet_ShockBeamFire(FireMode[Mode]).bUseEnhancedNetCode = true;
    ServerStartFire(mode);
}

simulated function SpawnBeamEffect(vector HitLocation, vector HitNormal, vector Start, rotator Dir, int ReflectNum)
{
    local ShockBeamEffect Beam;

    if (bClientDemoNetFunc)
    {
        Start.Z = Start.Z - 64.0;
    }
    Beam = Spawn(class'XWeapons.ShockBeamEffect',,, Start, Dir);
    if (Beam != None)
    {
        Beam.RemoteRole = ROLE_None;
        if (ReflectNum != 0)
        {
            // prevents client side repositioning of beam start
            Beam.Instigator = None;
        }
        Beam.AimAt(HitLocation, HitNormal);
    }
}

DefaultProperties
{
    FireModeClass(0)=class'NewNet_ShockBeamFire'
    FireModeClass(1)=class'NewNet_ShockProjFire'
}
