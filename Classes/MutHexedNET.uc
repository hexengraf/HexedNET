class MutHexedNET extends HxMutator;

const AVERDT_SEND_PERIOD = 4.00;

var config bool bAllowEnhancedNetcode;
var config bool bAllowNewEyeHeightAlgorithm;
var config float TimeBetweenPings;
var config float PawnCollisionTimeWindow;

var PawnCollisionCopy PCC;
var float ClientTimeStamp;
var float AverDT;

var const private class<Weapon> WeaponClasses[13];
var const private class<Weapon> NewNetWeaponClasses[13];

var private TimeStamp_Pawn CounterPawn;
var private TimeStamp StampInfo;
var private float StampArray[256];
var private float Counter;
var private float LastReplicatedAverDT;
var private bool bEnhancedNetcodeActive;
var private bool bPawnClassReplaced;
var private bool bDefaultWeaponsChanged;

event PreBeginPlay()
{
    Super.PreBeginPlay();
    if (Level.NetMode != NM_Standalone)
    {
        SetupNewEyeHeightAlgorithm();
        SetupEnhancedNetcode();
    }
}

function SetupNewEyeHeightAlgorithm()
{
    if (bAllowNewEyeHeightAlgorithm)
    {
        if (Level.Game.DefaultPlayerClassName ~= "xGame.xPawn")
        {
            Level.Game.DefaultPlayerClassName = string(class'HxNTPawn');
            bPawnClassReplaced = true;
        }
        else
        {
            Warn(Name@"failed to replace xPawn class, disabling new eye height algorithm.");
            bAllowNewEyeHeightAlgorithm = false;
        }
    }
}

function SetupEnhancedNetcode()
{
    if (bAllowEnhancedNetcode)
    {
        StampInfo = Spawn(class'TimeStamp', Self);
        CounterPawn = Spawn(class'TimeStamp_Pawn', Self);
        SetupInstagib();
        bEnhancedNetcodeActive = true;
    }
}

function SetupInstagib()
{
    local MutInstagib Instagib;

    ForEach DynamicActors(class'MutInstagib', Instagib) break;

    if (Instagib != None)
    {
        Instagib.Default.WeaponName = 'NewNet_SuperShockRifle';
        Instagib.Default.WeaponString = string(class'NewNet_SuperShockRifle');
        Instagib.Default.DefaultWeaponName = string(class'NewNet_SuperShockRifle');
        Instagib.WeaponName = 'NewNet_SuperShockRifle';
        Instagib.WeaponString = string(class'NewNet_SuperShockRifle');
        Instagib.DefaultWeaponName = string(class'NewNet_SuperShockRifle');
    }
}

function ModifyPlayer(Pawn Other)
{
    if (bEnhancedNetcodeActive)
    {
        SpawnCollisionCopy(Other);
    }
    if (HxNTPawn(Other) != None)
    {
        HxNTPawn(Other).bAllowNewEyeHeightAlgorithm = bAllowNewEyeHeightAlgorithm;
    }
    Super.ModifyPlayer(Other);
}

function SpawnCollisionCopy(Pawn Other)
{
    if (PCC == None)
    {
        PCC = Spawn(class'PawnCollisionCopy');
        PCC.SetPawn(Other);
    }
    else
    {
        PCC.AddPawnToList(Other);
    }
    PCC = PCC.RemoveOldPawns();
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

function ReplaceOtherMutatorWeapons()
{
    local Mutator M;
    local int i;

    bDefaultWeaponsChanged = true;
    // replace DefaultWeaponName (fix for simple Arena mutators)
    for (M = Level.Game.BaseMutator; M != None; M = M.NextMutator)
    {
        if (M.DefaultWeaponName != "")
        {
            for (i = 0; i < ArrayCount(WeaponClasses); ++i)
            {
                if (M.DefaultWeaponName ~= string(WeaponClasses[i]))
                {
                    M.DefaultWeaponName = string(NewNetWeaponClasses[i]);
                }
            }
        }
    }
}

function Tick(float DeltaTime)
{
    if (bEnhancedNetcodeActive)
    {
        if (!bDefaultWeaponsChanged)
        {
            ReplaceOtherMutatorWeapons();
        }
        ClientTimeStamp += DeltaTime;
        Counter += 1;
        StampArray[Counter % 256] = ClientTimeStamp;
        AverDT = (9.0 * AverDT + DeltaTime) * 0.1;
        CounterPawn.UpdateCounter(Counter);
        if (ClientTimeStamp > LastReplicatedAverDT + AVERDT_SEND_PERIOD)
        {
            StampInfo.ReplicatedAverDT(AverDT);
            LastReplicatedAverDT = ClientTimeStamp;
        }
    }
}

function float GetStamp(int Stamp)
{
   return StampArray[Stamp % 256];
}

function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
    local WeaponLocker L;
    local int i;
    local int j;

    if (bEnhancedNetcodeActive)
    {
        if (xWeaponBase(Other) != None)
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

function GetServerDetails(out GameInfo.ServerResponseLine ServerState)
{
    local int i;

    Super.GetServerDetails(ServerState);
    i = ServerState.ServerInfo.Length;
    ServerState.ServerInfo.Length = i + 1;
    ServerState.ServerInfo[i].Key = "Enhanced netcode";
    ServerState.ServerInfo[i++].Value = Eval(bEnhancedNetcodeActive, "Enabled", "Disabled");
    i = ServerState.ServerInfo.Length;
    ServerState.ServerInfo.Length = i + 1;
    ServerState.ServerInfo[i].Key = "New EyeHeight algorithm";
    ServerState.ServerInfo[i++].Value = Eval(bPawnClassReplaced, "Enabled", "Disabled");
}

defaultproperties
{
    FriendlyName="HexedNET v7T1"
    Description="Cutdown version of UTComp providing enhanced netcode (NewNet Weapons) and enhanced eye height algorithm."
    bAddToServerPackages=true

    MutatorGroup="HexedNET"
    CRIClass=class'HxNTClient'
    Properties(0)=(Name="bAllowEnhancedNetcode",Section="Enhanced Netcode",Caption="Allow enhanced netcode",Hint="Allow clients to enable/disable the enhanced netcode.",Type="Check",bMPOnly=true,bAdvanced=true)
    Properties(1)=(Name="TimeBetweenPings",Section="Enhanced Netcode",Caption="Time between pings",Hint="Time to wait between pings (in seconds).",Type="Text",Data="4;0.0:360.0",bMPOnly=true,bAdvanced=true)
    Properties(2)=(Name="PawnCollisionTimeWindow",Section="Enhanced Netcode",Caption="Pawn collision time window",Hint="Time window (in seconds) to look back for pawn collisions.",Type="Text",Data="4;0.0:360.0",bMPOnly=true,bAdvanced=true)
    Properties(3)=(Name="bAllowNewEyeHeightAlgorithm",Section="EyeHeight Algorithm",Caption="Allow new EyeHeight algorithm",Hint="Allow clients to enable/disable the new EyeHeight algorithm.",Type="Check",bMPOnly=true)

    // configs
    bAllowEnhancedNetcode=true
    bAllowNewEyeHeightAlgorithm=true
    TimeBetweenPings=3.0
    PawnCollisionTimeWindow=0.35
    //original weapons
    WeaponClasses(0)=class'ShockRifle'
    WeaponClasses(1)=class'LinkGun'
    WeaponClasses(2)=class'Minigun'
    WeaponClasses(3)=class'FlakCannon'
    WeaponClasses(4)=class'RocketLauncher'
    WeaponClasses(5)=class'SniperRifle'
    WeaponClasses(6)=class'BioRifle'
    WeaponClasses(7)=class'AssaultRifle'
    WeaponClasses(8)=class'ClassicSniperRifle'
    WeaponClasses(9)=class'ONSAVRiL'
    WeaponClasses(10)=class'ONSMineLayer'
    WeaponClasses(11)=class'ONSGrenadeLauncher'
    WeaponClasses(12)=class'SuperShockRifle'
    // replaced NewNet classes
    NewNetWeaponClasses(0)=class'NewNet_ShockRifle'
    NewNetWeaponClasses(1)=class'NewNet_LinkGun'
    NewNetWeaponClasses(2)=class'NewNet_MiniGun'
    NewNetWeaponClasses(3)=class'NewNet_FlakCannon'
    NewNetWeaponClasses(4)=class'NewNet_RocketLauncher'
    NewNetWeaponClasses(5)=class'NewNet_SniperRifle'
    NewNetWeaponClasses(6)=class'NewNet_BioRifle'
    NewNetWeaponClasses(7)=class'NewNet_AssaultRifle'
    NewNetWeaponClasses(8)=class'NewNet_ClassicSniperRifle'
    NewNetWeaponClasses(9)=class'NewNet_ONSAVRiL'
    NewNetWeaponClasses(10)=class'NewNet_ONSMineLayer'
    NewNetWeaponClasses(11)=class'NewNet_ONSGrenadeLauncher'
    NewNetWeaponClasses(12)=class'NewNet_SuperShockRifle'
}
