//-----------------------------------------------------------
//   This class acts simulated collision for the copied
//   pawn, for use in lag compensated firing.
//   This is used mostly so we don't have to worry about screwing
//   with the physics of the actual pawn when moving about.
//
//
//  *    IF YOU AREN'T DOING A TRACE ON THIS COPY,
//   MAKE ABSOLUTELY SURE ITS COLLISION IS TURNED OFF */
//-----------------------------------------------------------
class PawnCollisionCopy extends Actor;

struct PawnHistoryElement
{
    var float Timestamp;
    var Vector Location;
    var Rotator Rotation;
    var bool bCrouched;
};

var PawnCollisionCopy Next;
var Pawn CopiedPawn;

var private MutHexedNET HexedNET;
var private array<PawnHistoryElement> Snapshots;
var private float MaxDeltaTime;
var private float DefaultCollisionRadius;
var private float DefaultCollisionHeight;
var private float CrouchRadius;
var private float CrouchHeight;
var private bool bCrouched;

function PostBeginPlay()
{
    Super.PostBeginPlay();
    HexedNET = MutHexedNET(Owner);
    MaxDeltaTime = HexedNET.GetDeltaTimeLimit();
}

// Set up the collision properties of our copy
function SetPawn(Pawn Other)
{
    if (Other == None)
    {
        Warn("PawnCopy spawned without proper Other");
        // Destroy();
        return;
    }
    CopiedPawn = Other;
    DefaultCollisionRadius = CopiedPawn.default.CollisionRadius;
    DefaultCollisionHeight = CopiedPawn.default.CollisionHeight;
    CrouchHeight = CopiedPawn.CrouchHeight;
    CrouchRadius = CopiedPawn.CrouchRadius;
    bUseCylinderCollision = CopiedPawn.bUseCylinderCollision;
    bCrouched = CopiedPawn.bIsCrouched;
    // If we cant use simple collisions, set up the mesh
    if (!bUseCylinderCollision)
    {
        // snarf LinkMesh is causing crashes, works ok without it
        if (HexedNET.bLinkMeshes)
        {
            // This is required for high pingers to be able to hit vehicles properly;
            // cylinders don't work - Calypto
            LinkMesh(CopiedPawn.Mesh);
        }
        // for weapon pawn, we need the vehicle's collision radius, not the turret
        if(ONSWeaponPawn(CopiedPawn) != None)
        {
            // Check if the VehicleBase actually exists before accessing its properties
            if (ONSWeaponPawn(CopiedPawn).VehicleBase != None)
            {
                SetCollisionSize(
                    ONSWeaponPawn(CopiedPawn).VehicleBase.CollisionRadius,
                    ONSWeaponPawn(CopiedPawn).VehicleBase.CollisionHeight);
            }
            else
            {
                // Fallback to the turret's own collision if VehicleBase is missing
                SetCollisionSize(CopiedPawn.CollisionRadius, CopiedPawn.CollisionHeight);
            }
        }
    }
    else
    {
        SetCollisionSize(CopiedPawn.CollisionRadius, CopiedPawn.CollisionHeight);
    }
}

// What happens if its not an xpawn and its changing shapes?
function GoToPawn()
{
    if (CopiedPawn != None)
    {
        SetLocation(CopiedPawn.Location);
        SetCollisionSize(CopiedPawn.CollisionRadius, CopiedPawn.CollisionHeight);
        if (bUseCylinderCollision)
        {
            if (!bCrouched && CopiedPawn.bIsCrouched)
            {
                SetCollisionSize(CrouchRadius, CrouchHeight);
                bCrouched = true;
            }
            else if (bCrouched && !CopiedPawn.bIsCrouched)
            {
                SetCollisionSize(DefaultCollisionRadius, DefaultCollisionHeight);
                bCrouched = false;
            }
        }
        SetCollision(true);
    }
}

// What happens if its not an xpawn and its changing shapes?
function RewindPawn(float DeltaTime)
{
    local float TargetTimestamp;
    local float Alpha;
    local int Lo;
    local int Up;

    if (CopiedPawn == None || CopiedPawn.DrivenVehicle != None)
    {
       return;
    }
    TargetTimestamp = Level.TimeSeconds - DeltaTime;
    SetCollision(false);
    if (Snapshots.Length == 0 || Snapshots[Snapshots.Length - 1].Timestamp < TargetTimestamp)
    {
        GoToPawn();
        return;
    }
    Lo = FindLowerBound(TargetTimestamp);
    if (Snapshots.Length > 1 && Snapshots[Lo].Timestamp < TargetTimestamp)
    {
        Up = Lo + 1;
        if (bUseCylinderCollision)
        {
            if (!bCrouched && Snapshots[Up].bCrouched && Snapshots[Lo].bCrouched)
            {
                SetCollisionSize(CrouchRadius, CrouchHeight);
                bCrouched = true;
            }
            else if (bCrouched && (!Snapshots[Up].bCrouched || !Snapshots[Lo].bCrouched))
            {
                SetCollisionSize(DefaultCollisionRadius, DefaultCollisionHeight);
                bCrouched = false;
            }
        }
        Alpha = GetAlpha(TargetTimestamp, Snapshots[Lo].Timestamp, Snapshots[Up].Timestamp);
        SetLocation(
            Snapshots[Up].Location + Alpha * (Snapshots[Lo].Location - Snapshots[Up].Location));
        // TODO: interpolate rotation?
        SetRotation(Snapshots[Up].Rotation);
    }
    else
    {
        // FixMe: This shouldn't need to be set unless it changes
        if (Snapshots[Lo].bCrouched)
        {
            SetCollisionSize(CrouchRadius, CrouchHeight);
        }
        else if (CopiedPawn.IsA('xPawn'))
        {
            SetCollisionSize(DefaultCollisionRadius, DefaultCollisionHeight);
        }
        else if (bUseCylinderCollision)
        {
            SetCollisionSize(CopiedPawn.CollisionRadius, CopiedPawn.CollisionHeight);
        }
        SetLocation(Snapshots[Lo].Location);
        SetRotation(Snapshots[Lo].Rotation);
    }
    // Without LinkMesh enabled, this logic will not let you hit the vehicle if the main seat is
    // occupied (if gunner then works fine) - Calypto
    // Do not enable collision for passenger seats to prevent the phantom cylinder shield
    // A vehicle attached to another vehicle is a passenger seat
    if (CopiedPawn.bCollideActors
        && (!CopiedPawn.IsA('Vehicle') || CopiedPawn.Base == None
            || !CopiedPawn.Base.IsA('Vehicle')))
    {
        // Enable collision for infantry and main vehicles
        SetCollision(true);
    }
}

function TurnOffCollision()
{
    SetCollision(false);
}

function AddPawnToList(Pawn Other)
{
    if (Next == None)
    {
        Next = Spawn(class'PawnCollisionCopy', HexedNET);
        Next.SetPawn(Other);
    }
    else
    {
       Next.AddPawnToList(Other);
    }
}

// Remove old pawns, returns what Next should be for the caller PawnCollisionCopies
function PawnCollisionCopy RemoveOldPawns()
{
    if (CopiedPawn == None)
    {
        Destroy();
        if (Next != None)
        {
            return Next.RemoveOldPawns();
        }
        return None;
    }
    if (Next != None)
    {
        Next = Next.RemoveOldPawns();
    }
    return Self;
}

// damage the copied pawn, NOT THIS
event TakeDamage(int Damage,
                 Pawn EventInstigator,
                 Vector HitLocation,
                 Vector Momentum,
                 class<DamageType> DamageType)
{
    // TODO: could some code be simplified by redirecting damage to CopiedPawn here?
    Warn("Pawn collision copy should never take damage");
}

event Destroyed()
{
    LinkMesh(None);
    Super.Destroyed();
}

function Identify()
{
    if (CopiedPawn == None)
    {
        Log("PCC: No pawn");
    }
    else if (CopiedPawn.PlayerReplicationInfo != None)
    {
        Log("PCC: Pawn"@CopiedPawn.PlayerReplicationInfo.PlayerName);
    }
    else
    {
        Log("PCC: Unnamed Pawn");
    }
}

function Tick(float DeltaTime)
{
    local float OldestTimestamp;
    local int i;

    if (CopiedPawn != None)
    {
        OldestTimestamp = Level.TimeSeconds - MaxDeltaTime;
        while (Snapshots.Length > 0 && Snapshots[0].Timestamp < OldestTimestamp)
        {
            Snapshots.Remove(0, 1);
        }
        i = Snapshots.Length;
        Snapshots.Length = i + 1;
        Snapshots[i].Timestamp = Level.TimeSeconds;
        Snapshots[i].Location = CopiedPawn.Location;
        Snapshots[i].Rotation = CopiedPawn.Rotation;
        Snapshots[i].bCrouched = CopiedPawn.bIsCrouched;
    }
}

function Rewind(float delta)
{
    local PawnCollisionCopy PCC;

    for (PCC = Self; PCC != None; PCC = PCC.Next)
    {
        PCC.RewindPawn(Delta);
    }
}

function UndoRewind()
{
    local PawnCollisionCopy PCC;

    for (PCC = Self; PCC != None; PCC = PCC.Next)
    {
        PCC.TurnOffCollision();
    }
}

// TODO: what about self-inflicted splash damage if target is close?
// By updating to collide in the current target location (instead of past location),
// players might wrongfully avoid self-inflicted splash damage.
function Vector GetPresentHitLocation(Vector HitLocation)
{
    // TODO: handle crouching differences
    return HitLocation + CopiedPawn.Location - Location;
}

final function int FindLowerBound(float Timestamp)
{
    local int Result;
    local int Middle;
    local int Low;
    local int High;

    Result = 0;
    Low = 0;
    if (Snapshots[Low].Timestamp <= Timestamp)
    {
        High = Snapshots.Length - 1;
        while (Low <= High)
        {
            Middle = (Low + High) / 2;
            if (Snapshots[Middle].Timestamp > Timestamp)
            {
                High = Middle - 1;
            }
            else
            {
                Result = Middle;
                Low = Middle + 1;
            }
        }
    }
    return Result;
}

final function float GetAlpha(float Value, float A, float B)
{
    return FClamp((B - Value) / (B - A), 0.0, 1.0);
}

defaultproperties
{
    RemoteRole=ROLE_None
    Physics=PHYS_None
    bCollideActors=false
    bCollideWorld=false
    bBlockActors=false
    bBlockPlayers=false
    bProjTarget=false
    bBlockProjectiles=false
    bDisturbFluidSurface=false
    bCanBeDamaged=false
    bAcceptsProjectors=false
    bCanTeleport=false
    bHidden=true
    bOnlyDirtyReplication=true
    bSkipActorPropertyReplication=true
    MaxDeltaTime=0.35
}
