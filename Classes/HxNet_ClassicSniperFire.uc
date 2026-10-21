class HxNet_ClassicSniperFire extends ClassicSniperFire
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTBaseInstantFire.uci

function DoTrace(Vector Start, Rotator Dir)
{
    local Actor Other;
    local Pawn HeadShotPawn;
    local SniperWallHitEffect S;
    local Vector X;
    local Vector End;
    local Vector HitLocation;
    local Vector HitNormal;
    local float CompensationTime;

    if (Level.NetMode == NM_Client || !WantsLagCompensation())
    {
        Super.DoTrace(Start,Dir);
        return;
    }
    X = Vector(Dir);
    End = Start + TraceRange * X;
    CompensationTime = Client.GetCompensationTime() + ServerDelay;
    Other = HexedNET.ReconTrace(
        Weapon, HitLocation, HitNormal, End, Start, CompensationTime, ClientHit);
    HexedNET.UndoRewind();
    if (Level.NetMode != NM_Standalone || PlayerController(Instigator.Controller) == None)
    {
        Weapon.Spawn(class'TracerProjectile', Instigator.Controller,, Start, Dir);
    }
    if (Other != None && Other != Instigator)
    {
        if (!Other.bWorldGeometry)
        {
            if (Vehicle(Other) != None)
            {
                HeadShotPawn = Vehicle(Other).CheckForHeadShot(HitLocation, X, 1.0);
            }
            if (HeadShotPawn != None)
            {
                HeadShotPawn.TakeDamage(
                    DamageMax * HeadShotDamageMult,
                    Instigator,
                    HitLocation,
                    Momentum * X,
                    DamageTypeHeadShot);
            }
            else if (Pawn(Other) != None && Pawn(Other).IsHeadShot(HitLocation, X, 1.0))
            {
                Other.TakeDamage(
                    DamageMax * HeadShotDamageMult,
                    Instigator,
                    HitLocation,
                    Momentum * X,
                    DamageTypeHeadShot);
            }
            else
            {
                Other.TakeDamage(
                    DamageMax, Instigator, HitLocation, Momentum * X, DamageType);
            }
        }
        else
        {
            HitLocation = HitLocation + 2.0 * HitNormal;
        }
    }
    else
    {
        HitLocation = End;
        HitNormal = Normal(Start - End);
    }
    if (HitNormal != Vect(0, 0, 0) && HitScanBlockingVolume(Other) == None)
    {
        S = Weapon.Spawn(class'SniperWallHitEffect',,, HitLocation, Rotator(-1 * HitNormal));
        if (S != None)
        {
            S.FireStart = Start;
        }
    }
}

function GetStartAndAim(out Vector Start, out Rotator Aim)
{
    Start = Instigator.Location + Instigator.EyePosition();
    Aim = AdjustAim(Start, AimError);
}

defaultproperties
{
    BASLocationTolerance=360
    BASAngleTolerance=-0.5
    bClientFireEffect=false
}
