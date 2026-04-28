
class NewNet_FlakShell extends FlakShell;

const INTERP_TIME = 0.50;

var private PlayerController PC;
var private HxNTClient Client;
var private FakeProjectileManager FPM;
var private vector DesiredDeltaFake;
var private float CurrentDeltaFakeTime;
var private bool bInterpFake;
var private bool bOwned;

replication
{
    unreliable if (bDemoRecording)
        DoMove, DoSetLoc;
}

#include Classes\Include\WeaponProjectileBaseFunctions.uci

simulated function PostNetBeginPlay()
{
    Super.PostNetBeginPlay();
    DoCheckForFakeProj();
}

simulated function bool CheckForFakeProj()
{
    local Projectile FP;

    ValidateFPM();
    FP = FPM.GetFP(class'NewNet_Fake_FlakShell');
    if (FP != None)
    {
        // bInterpFake = true;
        DesiredDeltaFake = Location - FP.Location;
        doSetLoc(FP.Location);
        FPM.RemoveProjectile(FP);
        bOwned = False;
        return true;
    }
    return false;
}

defaultproperties
{
}
