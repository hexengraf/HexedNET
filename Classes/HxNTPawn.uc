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

// override to fix None access
function ServerChangedWeapon(Weapon OldWeapon, Weapon NewWeapon)
{
	local float InvisTime;

	if ( bInvis )
	{
	    if ( (OldWeapon != None) && (OldWeapon.OverlayMaterial == InvisMaterial) )
		    InvisTime = OldWeapon.ClientOverlayCounter;
	    else
		    InvisTime = 20000;
	}
    if (HasUDamage() || bInvis)
        SetWeaponOverlay(None, 0.f, true);

    Super(UnrealPawn).ServerChangedWeapon(OldWeapon, NewWeapon);

    if (bInvis)
        SetWeaponOverlay(InvisMaterial, InvisTime, true);
    else if (HasUDamage())
        SetWeaponOverlay(UDamageWeaponMaterial, UDamageTime - Level.TimeSeconds, false);

    // check for none here
    if(Weapon != None)
    {
        if (bBerserk)
            Weapon.StartBerserk();
        else if ( Weapon.bBerserk )
            Weapon.StopBerserk();
    }
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
