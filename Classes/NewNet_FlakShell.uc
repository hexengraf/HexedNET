
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

simulated function PostNetBeginPlay()
{
    Super.PostNetBeginPlay();
    DoCheckForFakeProj();
}

simulated function bool ValidateClient()
{
    if (Client != None)
    {
        return true;
    }
    if (Level.NetMode == NM_Client)
    {
        foreach DynamicActors(class'HxNTClient', Client) break;
    }
    return Client != None;
}

simulated function bool IsEnhancedNetcodeEnabled()
{
    return ValidateClient() && Client.IsEnhancedNetcodeEnabled();
}

simulated function DoCheckForFakeProj()
{
    if(Level.NetMode == NM_Client)
    {
        PC = Level.GetLocalPlayerController();
        if (CheckOwned())
        {
            CheckForFakeProj();
        }
    }
}

simulated function DoMove(Vector V)
{
    Move(V);
}

simulated function DoSetLoc(Vector V)
{
    SetLocation(V);
}

simulated function bool CheckOwned()
{
    if (!IsEnhancedNetcodeEnabled())
    {
        return false;
    }
    bOwned = PC != None && PC.Pawn != None && PC.Pawn == Instigator;
    return bOwned;
}

simulated function ValidateFPM()
{
    if (FPM == None)
    {
        foreach DynamicActors(class'FakeProjectileManager', FPM) break;
    }
}

simulated function FakeInterp(float DT)
{
    local vector V;
    local float OldDeltaFakeTime;

    V = DesiredDeltaFake * DT / INTERP_TIME;

    OldDeltaFakeTime = CurrentDeltaFakeTime;
    CurrentDeltaFakeTime += DT;

    if (CurrentDeltaFakeTime < INTERP_TIME)
    {
        DoMove(V);
    }
    else // (We overshot)
    {
        DoMove((INTERP_TIME - OldDeltaFakeTime) / DT * V);
        bInterpFake = False;
        //Turn off checking for fakes
    }
}

simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    if (Level.NetMode == NM_Client)
    {
        if (bInterpFake)
        {
            FakeInterp(DeltaTime);
        }
        else if (bOwned)
        {
            CheckForFakeProj();
        }
    }
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
