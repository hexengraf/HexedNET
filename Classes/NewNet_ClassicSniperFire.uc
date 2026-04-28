class NewNet_ClassicSniperFire extends ClassicSniperFire;

#include Classes\Include\WeaponFireBase.uci

function DoTrace(vector Start, Rotator Dir)
{
    local Actor Other;
    local Pawn HeadShotPawn;
    local SniperWallHitEffect S;
    local vector X;
    local vector End;
    local vector HitLocation;
    local vector HitNormal;
    local vector PresentHitLocation;

    if(!IsEnhancedNetcodeEnabled())
    {
        super.DoTrace(Start,Dir);
        return;
    }
    X = vector(Dir);
    End = Start + TraceRange * X;
    HexedNET.TimeTravel(PingDT);
    Other = HexedNET.CompensatedTrace(
            pingDT, Weapon, PresentHitLocation, HitLocation, HitNormal, End, Start);
    HexedNET.UnTimeTravel();
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
                HeadShotPawn = Vehicle(Other).CheckForHeadShot(PresentHitLocation, X, 1.0);
            }
            if (HeadShotPawn != None)
            {
                HeadShotPawn.TakeDamage(
                    DamageMax * HeadShotDamageMult,
                    Instigator,
                    PresentHitLocation,
                    Momentum * X,
                    DamageTypeHeadShot);
            }
 			else if (Pawn(Other) != None && Pawn(Other).IsHeadShot(HitLocation, X, 1.0))
            {
                Other.TakeDamage(
                    DamageMax * HeadShotDamageMult,
                    Instigator,
                    PresentHitLocation,
                    Momentum * X,
                    DamageTypeHeadShot);
            }
            else
            {
                Other.TakeDamage(
                    DamageMax, Instigator, PresentHitLocation, Momentum * X, DamageType);
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
    if (HitNormal != Vect(0,0,0) && HitScanBlockingVolume(Other) == None)
    {
		S = Weapon.Spawn(class'SniperWallHitEffect',,, HitLocation, rotator(-1 * HitNormal));
		if (S != None)
        {
			S.FireStart = Start;
        }
	}
}

DefaultProperties
{
}
