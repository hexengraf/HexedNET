class NewNet_SuperShockRifle extends SuperShockRifle
    HideDropDown
    CacheExempt;

#include Classes\Include\WeaponBaseShockRifle.uci

simulated function DoInstantFireEffect(int Mode)
{
    NewNet_SuperShockBeamFire(FireMode[Mode]).DoInstantFireEffect();
}

function NewNet_ServerStartFire(byte Mode, byte ClientCounter, float DT, ReplicatedRotator R, ReplicatedVector V, bool bBelievesHit, actor A/*, bool bBelievesHit, ReplicatedVector BelievedHLDelta, Actor A, vector HN, vector HL*/)
{
    if (!ServerShouldStartFire())
    {
        return;
    }
    ValidateNETClockPointer();
    NewNet_SuperShockBeamFire(FireMode[Mode]).PingDT = NETClock.GetPingDT(ClientCounter, DT);
    NewNet_SuperShockBeamFire(FireMode[Mode]).bUseEnhancedNetCode = true;
    NewNet_SuperShockBeamFire(FireMode[Mode]).AverDT = NETClock.ServerAverDT;

    if (bBelievesHit)
    {
        NewNet_SuperShockBeamFire(FireMode[Mode]).BelievedHitActor = A;
    }
    NewNet_SuperShockBeamFire(FireMode[Mode]).bBelievesHit = bBelievesHit;
    NewNet_SuperShockBeamFire(FireMode[Mode]).bFirstGo = true;
    if (FireMode[Mode].NextFireTime <= Level.TimeSeconds + FireMode[Mode].PreFireTime
        && StartFire(Mode))
    {
        FireMode[Mode].ServerStartFireTime = Level.TimeSeconds;
        FireMode[Mode].bServerDelayStartFire = false;
        NewNet_SuperShockBeamFire(FireMode[Mode]).SavedVec.X = V.X;
        NewNet_SuperShockBeamFire(FireMode[Mode]).SavedVec.Y = V.Y;
        NewNet_SuperShockBeamFire(FireMode[Mode]).SavedVec.Z = V.Z;
        NewNet_SuperShockBeamFire(FireMode[Mode]).SavedRot.Yaw = R.Yaw;
        NewNet_SuperShockBeamFire(FireMode[Mode]).SavedRot.Pitch = R.Pitch;
        NewNet_SuperShockBeamFire(FireMode[Mode]).bUseReplicatedInfo =
            IsReasonable(NewNet_SuperShockBeamFire(FireMode[Mode]).SavedVec);
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
    NewNet_SuperShockBeamFire(FireMode[Mode]).PingDT = NETClock.GetPingDT(ClientCounter, DT);
    NewNet_SuperShockBeamFire(FireMode[Mode]).bUseEnhancedNetCode = true;
    ServerStartFire(Mode);
}

simulated function SpawnBeamEffect(vector HitLocation, vector HitNormal, vector Start, rotator Dir, int ReflectNum)
{
    local ShockBeamEffect Beam;

    if (bClientDemoNetFunc) {
        Start.Z = Start.Z - 64.0;
    }
    if (Instigator.PlayerReplicationInfo.Team != None
        && Instigator.PlayerReplicationInfo.Team.TeamIndex == 1)
    {
        Beam = Spawn(class'XWeapons.BlueSuperShockBeam',,, Start, Dir);
    }
    else
    {
        Beam = Spawn(class'XWeapons.SuperShockBeamEffect',,, Start, Dir);
    }
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
    FireModeClass(0)=class'NewNet_SuperShockBeamFire'
    FireModeClass(1)=class'NewNet_SuperShockBeamFire'
}
