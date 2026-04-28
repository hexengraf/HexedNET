
class NewNet_ShockProjectile extends ShockProjectile;

const INTERP_TIME = 0.70;

var private PlayerController PC;
var private HxNTClient Client;
var private FakeProjectileManager FPM;
var private vector DesiredDeltaFake;
var private float CurrentDeltaFakeTime;
var private bool bInterpFake;
var private bool bOwned;
var private bool bMoved;

replication
{
    unreliable if (bDemoRecording)
        DoMove, DoSetLoc;
}

#include Classes\Include\WeaponProjectileBaseFunctions.uci

simulated function PostNetBeginPlay()
{
    Super.PostNetBeginPlay();
    if (Level.NetMode == NM_Client)
    {
        PC = Level.GetLocalPlayerController();
        if (CheckOwned())
        {
            if (!CheckForFakeProj())
            {
                bMoved = true;
                DoMove(FMax(0.00, (class'HxNTClient'.default.AveragePing - 1.5 * class'HxNTClock'.default.AverDT)) * Velocity);
            }
        }
    }
}

simulated function bool CheckForFakeProj()
{
    local Projectile FP;
    local float Ping;

    ValidateFPM();
    FP = FPM.GetFP(class'NewNet_Fake_ShockProjectile');
    if (FP != None)
    {
        bInterpFake = true;
        if (bMoved)
        {
            DesiredDeltaFake = Location - FP.Location;
        }
        else
        {
            Ping = FMax(0.0, class'HxNTClient'.default.AveragePing - 1.5 * class'HxNTClock'.default.AverDT);
            DesiredDeltaFake = (Location+Velocity*Ping) - FP.Location;
        }
        DoSetLoc(FP.Location);
        FPM.RemoveProjectile(FP);
        bOwned = false;
        return true;
    }
    return false;
}

defaultproperties
{
}
