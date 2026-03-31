class HxNTPawn extends xPawn;

var config bool bNewEyeHeightAlgorithm;
var config bool bViewSmoothing;
var bool bAllowNewEyeHeightAlgorithm;

// UpdateEyeHeight related
var private EPhysics OldPhysics2;
var private vector OldLocation;
var private float OldBaseEyeHeight;
var private int IgnoreZChangeTicks;
var private float EyeHeightOffset;

replication
{
    reliable if (Role == ROLE_Authority)
        bAllowNewEyeHeightAlgorithm;
}

simulated event PostNetBeginPlay()
{
    Super.PostNetBeginPlay();
    OldBaseEyeHeight = Default.BaseEyeHeight;
    OldLocation = Location;
}

simulated function ClientRestart()
{
    Super.ClientRestart();
    IgnoreZChangeTicks = 1;
}

simulated function Touch(Actor Other)
{
    Super.Touch(Other);
    if (Other != None && Other.IsA('Teleporter'))
    {
        IgnoreZChangeTicks = 2;
    }
}

event UpdateEyeHeight(float DeltaTime)
{
    local vector Delta;

    if (WantsOldUpdateEyeHeight())
    {
        Super.UpdateEyeHeight(DeltaTime);
        return;
    }
    if (WantsSmoothedView())
    {
        Delta = Location - OldLocation;
        // remove lifts from the equation.
        if (Base != None)
        {
            Delta -= DeltaTime * Base.Velocity;
        }
        // Step detection heuristic
        if (IgnoreZChangeTicks == 0 && Abs(Delta.Z) > DeltaTime * GroundSpeed)
        {
            EyeHeightOffset += FClamp(Delta.Z, -MAXSTEPHEIGHT, MAXSTEPHEIGHT);
        }
    }
    OldLocation = Location;
    OldPhysics2 = Physics;
    if (IgnoreZChangeTicks > 0)
    {
        IgnoreZChangeTicks--;
    }
    if (WantsSmoothedView())
    {
        EyeHeightOffset += BaseEyeHeight - OldBaseEyeHeight;
    }
    OldBaseEyeHeight = BaseEyeHeight;
    EyeHeightOffset *= Exp(-9.0 * DeltaTime);
    EyeHeight = BaseEyeHeight - EyeHeightOffset;
    Controller.AdjustView(DeltaTime);
}

function bool WantsOldUpdateEyeHeight()
{
    return Level.NetMode == NM_DedicatedServer
        || Controller == None
        || !bAllowNewEyeHeightAlgorithm
        || !bNewEyeHeightAlgorithm
        || bJustLanded
        || bLandRecovery
        || bTearOff;
}

function bool WantsSmoothedView()
{
    return ((Physics == PHYS_Walking || Physics == PHYS_Spider)
            && (bViewSmoothing || !bJustLanded))
        || (Physics == PHYS_Falling && OldPhysics2 == PHYS_Walking);
}

simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    // fix annoying bug where sometimes weapon instigator gets set to none
    // due to race condition in replication
    if(Level.NetMode == NM_Client && Weapon != None && Weapon.Instigator != Self)
    {
        Weapon.Instigator = Self;
    }
}

defaultproperties
{
    bAlwaysRelevant=True
    bNewEyeHeightAlgorithm=True
    bViewSmoothing=True
}
