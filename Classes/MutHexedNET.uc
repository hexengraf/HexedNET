class MutHexedNET extends HxMutator;

var config float MaxPingFrequency;
var config float PawnCollisionTimeWindow;
var config bool bRubberbandingFix;

var HxNTClock NETClock;

var const private class<Weapon> WeaponClasses[13];
var const private class<Weapon> NewNetWeaponClasses[13];
var const private class<WeaponFire> WeaponFireClasses[5];
var const private class<WeaponFire> NewNetWeaponFireClasses[5];
var private PawnCollisionCopy PCC;

event PreBeginPlay()
{
    Super.PreBeginPlay();
    if (!bDeleteMe && !bPendingDelete)
    {
        NETClock = Spawn(class'HxNTClock', Self);
        ApplyNewNetWeaponsOnMutators();
        if (bRubberbandingFix)
        {
            Level.Game.PlayerControllerClassName = string(class'HxNTPlayer');
        }
    }
}

function bool MutatorIsAllowed()
{
    return Super.MutatorIsAllowed() && Level.NetMode != NM_Standalone;
}

function ApplyNewNetWeaponsOnMutators()
{
    local Mutator M;

    for (M = Level.Game.BaseMutator; M != None; M = M.NextMutator)
    {
        if (M.DefaultWeaponName != "")
        {
            ApplyNewNetWeapons(M);
        }
    }
}

function ApplyNewNetWeapons(Mutator M)
{
    local int i;

    for (i = 0; i < ArrayCount(WeaponClasses); ++i)
    {
        if (M.DefaultWeaponName ~= string(WeaponClasses[i]))
        {
            M.DefaultWeaponName = string(NewNetWeaponClasses[i]);
            if (M.DefaultWeapon != None)
            {
                M.DefaultWeapon = class<Weapon>(
                    DynamicLoadObject(M.DefaultWeaponName, class'Class'));
            }
            if (MutInstaGib(M) != None)
            {
                MutInstaGib(M).WeaponName = NewNetWeaponClasses[i].Name;
                MutInstaGib(M).WeaponString = M.DefaultWeaponName;
            }
        }
    }
}

function AddMutator(Mutator M)
{
    Super.AddMutator(M);
    if (M.DefaultWeaponName != "")
    {
        ApplyNewNetWeapons(M);
    }
}

function ModifyPlayer(Pawn Other)
{
    if (PCC == None)
    {
        PCC = Spawn(class'PawnCollisionCopy', Self);
        PCC.SetPawn(Other);
    }
    else
    {
        PCC.AddPawnToList(Other);
    }
    PCC = PCC.RemoveOldPawns();
    Super.ModifyPlayer(Other);
}

function TimeTravel(float delta)
{
    if (PCC != None)
    {
        PCC.TimeTravel(Delta);
    }
}

function UnTimeTravel()
{
    if (PCC != None)
    {
        PCC.UnTimeTravel();
    }
}

// We need to do 2 traces. First, one that ignores the things which have already been copied
// and a second one that looks only for things that are copied
function Actor TimeTravelTrace(Weapon Weapon,
                               out vector HitLocation,
                               out vector HitNormal,
                               vector End,
                               vector Start)
{
    local Actor Other;
    local PawnCollisionCopy Copy;
    local vector PCCHitNormal;
    local vector PCCHitLocation;

    // First, lets set the extent of our trace.  End once we hit an actor which won't
    // be checked by an unlagged copy.
    foreach TraceActors(class'Actor', Other, HitLocation, HitNormal, End, Start)
    {
        if ((Other.bBlockActors || Other.bProjTarget || Other.bWorldGeometry)
            && !class'MutHexedNET'.static.IsPredicted(Other))
        {
            End = HitLocation;
            break;
        }
    }
    // Now, lets see if we run into any copies, we stop at the location
    // determined by the previous trace.
    foreach TraceActors(class'PawnCollisionCopy', Copy, PCCHitLocation, PCCHitNormal, End, Start)
    {
        if (Copy != None && Copy.CopiedPawn != None && Copy.CopiedPawn != Weapon.Instigator)
        {
            HitLocation = PCCHitLocation;
            HitNormal = PCCHitNormal;
            return Copy;
        }
    }
    return Other;
}

function Actor CompensatedTrace(float Delta,
                                Weapon Weapon,
                                out vector PresentHitLocation,
                                out vector HitLocation,
                                out vector HitNormal,
                                vector End,
                                vector Start)
{
    local Actor Other;

    if (Delta <= 0.0)
    {
        Other = Weapon.Trace(HitLocation, HitNormal, End, Start, true);
    }
    else
    {
        Other = TimeTravelTrace(Weapon, HitLocation, HitNormal, End, Start);
    }
    if (Other != None && Other.IsA('PawnCollisionCopy'))
    {
        PresentHitLocation = PawnCollisionCopy(Other).GetPresentHitLocation(HitLocation);
        return PawnCollisionCopy(Other).CopiedPawn;
    }
    PresentHitLocation = HitLocation;
    return Other;
}

function Actor CompensatedTrace2(float Delta,
                                 Weapon Weapon,
                                 out vector PresentHitLocation,
                                 out vector HitLocation,
                                 out vector HitNormal,
                                 vector End,
                                 vector Start,
                                 bool bBelievesHit,
                                 Actor BelievedHitActor)
{
    local Actor Other;
    local Actor AltOther;
    local vector AltPresentHitLocation;
    local vector AltHitLocation;
    local vector altHitNormal;
    local float f;

    Other = CompensatedTrace(Delta, Weapon, PresentHitLocation, HitLocation, HitNormal, End, Start);
    f = 0.02;
    if (bBelievesHit && Other != BelievedHitActor)
    {
        while (Abs(f) < 0.04 + (2.0 * NETClock.AverDT))
        {
            TimeTravel(Delta - f);
            AltOther = CompensatedTrace(
                Delta - f, Weapon, AltPresentHitLocation, AltHitLocation, AltHitNormal, End, Start);
            if (AltOther == BelievedHitACtor)
            {
                // Log("Fixed At"@f@"with max"@(0.04 + 2.0*NETClock.AverDT));
                Other = AltOther;
                PresentHitLocation = AltPresentHitLocation;
                HitLocation = AltHitLocation;
                f = 10.0;
            }
            if (f > 0.00)
            {
                f = -1.0 * f;
            }
            else
            {
                f = -1.0 * f + 0.02;
            }
        }
        // if (abs(f) < 9.0) log("Failed to fix");
    }
    else if (!bBelievesHit && Other != None && (Other.IsA('xPawn') || Other.IsA('Vehicle')))
    {
        while (Abs(f) < 0.04 + (2.0 * NETClock.AverDT))
        {
            AltOther = None;
            TimeTravel(Delta - f);
            AltOther = CompensatedTrace(
                Delta - f, Weapon, AltPresentHitLocation, AltHitLocation, AltHitNormal, End, Start);
            if (AltOther == None || !(AltOther.IsA('xPawn') || AltOther.IsA('Vehicle')))
            {
                // Log("Reverse Fixed At"@f);
                Other = AltOther;
                PresentHitLocation = AltPresentHitLocation;
                HitLocation = AltHitLocation;
                f=10.0;
            }
            if (f > 0.00)
            {
                f = -1.0 * f;
            }
            else
            {
                f = -1.0 * f + 0.02;
            }
        }
        // if (abs(f) < 9.0) log("Failed to reverse fix");
    }
    return Other;
}

function DriverEnteredVehicle(Vehicle V, Pawn P)
{
    local PawnCollisionCopy C;

    C = PCC;
    while (C != None)
    {
        if (C.CopiedPawn == P)
        {
            C.SetPawn(V);
            break;
        }
        C = C.Next;
    }
    Super.DriverEnteredVehicle(V, P);
}

function DriverLeftVehicle(Vehicle V, Pawn P)
{
    local PawnCollisionCopy C;

    C = PCC;
    while (C != None)
    {
        if (C.CopiedPawn == V)
        {
            C.SetPawn(P);
            break;
        }
        C = C.Next;
    }
    Super.DriverLeftVehicle(V, P);
}

function ListPawns()
{
    local PawnCollisionCopy PCC2;

    for (PCC2 = PCC; PCC2 != None; PCC2 = PCC2.Next)
    {
       PCC2.Identify();
    }
}

static function bool IsPredicted(Actor A)
{
    // Fix up vehicle a bit, we still wanna predict if its in the list w/o a driver
    return A == None || A.IsA('xPawn') || (A.IsA('Vehicle') && Vehicle(A).Driver != None);
}

function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
    local WeaponLocker L;
    local int i;
    local int j;

    if (Weapon(Other) != None)
    {
        for (i = 0; i < ArrayCount(Weapon(Other).FireModeClass); ++i)
        {
            for (j = 0; j < ArrayCount(WeaponFireClasses); ++j)
            {
                if (Weapon(Other).FireModeClass[i] == WeaponFireClasses[j])
                {
                    Weapon(Other).FireModeClass[i] = NewNetWeaponFireClasses[j];
                    break;
                }
            }
        }
    }
    else if (xWeaponBase(Other) != None)
    {
        for (i = 0; i < ArrayCount(WeaponClasses); ++i)
        {
            if (xWeaponBase(Other).WeaponType == WeaponClasses[i])
            {
                xWeaponBase(Other).WeaponType = NewNetWeaponClasses[i];
            }
        }
    }
    else if (WeaponPickup(Other) != None)
    {
        for (i = 0; i < ArrayCount(WeaponClasses); ++i)
        {
            if (WeaponPickup(Other).InventoryType == WeaponClasses[i])
            {
                WeaponPickup(Other).InventoryType = NewNetWeaponClasses[i];
            }
        }
    }
    else if (WeaponLocker(Other) != None)
    {
        L = WeaponLocker(Other);
        for (i = 0; i < ArrayCount(WeaponClasses); ++i)
        {
            for (j = 0; j < L.Weapons.Length; ++j)
            {
                if (L.Weapons[j].WeaponClass == WeaponClasses[i])
                {
                    L.Weapons[j].WeaponClass = NewNetWeaponClasses[i];
                }
            }
        }
    }
    return Super.CheckReplacement(Other, bSuperRelevant);
}

function string GetInventoryClassOverride(string InventoryClassName)
{
    local int i;

    InventoryClassName = Super.GetInventoryClassOverride(InventoryClassName);
    for (i = 0; i < ArrayCount(WeaponClasses); ++i)
    {
        if (InventoryClassName ~= string(WeaponClasses[i]))
        {
            return string(NewNetWeaponClasses[i]);
        }
    }
    return InventoryClassName;
}

defaultproperties
{
    FriendlyName="HexedNET v9dev"
    Description="Modified version of UTComp's enhanced netcode (ping compensation)."
    bAddToServerPackages=true
    CRIClass=class'HxNTClient'
    Properties(0)=(Name="MaxPingFrequency",Type=HX_PROPERTY_Float,LowerLimit="0.2",UpperLimit="20.0")
    Properties(1)=(Name="PawnCollisionTimeWindow",Type=HX_PROPERTY_Float,LowerLimit="0.05",UpperLimit="1.5")
    Properties(2)=(Name="bRubberbandingFix",Type=HX_PROPERTY_Bool)
    DisplayInfo(0)=(Caption="Maximum ping frequency",Hint="Maximum frequency to send pings (pings/second).",bMPOnly=true,bAdvanced=true)
    DisplayInfo(1)=(Caption="Pawn collision time window",Hint="Time window (in seconds) to look back for pawn collisions.",bMPOnly=true,bAdvanced=true)
    DisplayInfo(2)=(Caption="Backport rubberbanding fix",Hint="Backport OldUnreal's rubberbanding fix. Applied on restart/map change.")
    bDisableTick=true

    // configs
    MaxPingFrequency=10.0
    PawnCollisionTimeWindow=0.35
    bRubberbandingFix=false
    //original weapons
    WeaponClasses(0)=class'ShockRifle'
    WeaponClasses(1)=class'LinkGun'
    WeaponClasses(2)=class'FlakCannon'
    WeaponClasses(3)=class'RocketLauncher'
    WeaponClasses(4)=class'SniperRifle'
    WeaponClasses(5)=class'BioRifle'
    WeaponClasses(6)=class'SuperShockRifle'
    WeaponClasses(7)=class'ZoomSuperShockRifle'
    WeaponClasses(8)=class'HxSuperShockRifle'
    WeaponClasses(9)=class'HxZoomSuperShockRifle'
    // replaced NewNet classes
    NewNetWeaponClasses(0)=class'NewNet_ShockRifle'
    NewNetWeaponClasses(1)=class'NewNet_LinkGun'
    NewNetWeaponClasses(2)=class'NewNet_FlakCannon'
    NewNetWeaponClasses(3)=class'NewNet_RocketLauncher'
    NewNetWeaponClasses(4)=class'NewNet_SniperRifle'
    NewNetWeaponClasses(5)=class'NewNet_BioRifle'
    NewNetWeaponClasses(6)=class'NewNet_SuperShockRifle'
    NewNetWeaponClasses(7)=class'NewNet_ZoomSuperShockRifle'
    NewNetWeaponClasses(8)=class'NewNet_HxSuperShockRifle'
    NewNetWeaponClasses(9)=class'NewNet_HxZoomSuperShockRifle'
    WeaponFireClasses(0)=class'AssaultFire'
    WeaponFireClasses(1)=class'AssaultGrenade'
    WeaponFireClasses(2)=class'MiniGunFire'
    WeaponFireClasses(3)=class'MiniGunAltFire'
    WeaponFireClasses(4)=class'ClassicSniperFire'
    NewNetWeaponFireClasses(0)=class'NewNet_AssaultFire'
    NewNetWeaponFireClasses(1)=class'NewNet_AssaultGrenade'
    NewNetWeaponFireClasses(2)=class'NewNet_MiniGunFire'
    NewNetWeaponFireClasses(3)=class'NewNet_MiniGunAltFire'
    NewNetWeaponFireClasses(4)=class'NewNet_ClassicSniperFire'
}
