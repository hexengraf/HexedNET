
class NewNet_FlakChunk extends FlakChunk;

const INTERP_TIME = 1.00;

var int Index;

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

    reliable if (Role == ROLE_Authority && bNetInitial)
        Index;
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
    FP = FPM.GetFP(class'NewNet_Fake_FlakChunk', Index);
    if (FP != None)
    {
        bInterpFake = true;
        DesiredDeltaFake = Location - FP.Location;
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
