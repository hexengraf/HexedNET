class HxNTPawnTracker extends Actor;

struct PawnHistoryElement
{
    var float Timestamp;
    var Vector Location;
    var Rotator Rotation;
    var bool bCrouched;
};

var Pawn Tracked;
var private MutHexedNET HexedNET;
var private array<PawnHistoryElement> Snapshots;
var private float DefaultCollisionRadius;
var private float DefaultCollisionHeight;
var private float CrouchRadius;
var private float CrouchHeight;
var private bool bCrouched;

function PostBeginPlay()
{
    Super.PostBeginPlay();
    HexedNET = MutHexedNET(Owner);
}

function SetTracked(Pawn P)
{
    if (P == None)
    {
        Warn("PawnCopy spawned without proper pawn");
        return;
    }
    Tracked = P;
    bUseCylinderCollision = Tracked.bUseCylinderCollision;
    DefaultCollisionRadius = Tracked.default.CollisionRadius;
    DefaultCollisionHeight = Tracked.default.CollisionHeight;
    CrouchHeight = Tracked.CrouchHeight;
    CrouchRadius = Tracked.CrouchRadius;
    bCrouched = Tracked.bIsCrouched;
    if (!bUseCylinderCollision)
    {
        if (HexedNET.bLinkMeshes)
        {
            // Comments from WSUTComp:
            // snarf: LinkMesh is causing crashes, works ok without it
            // This is required for high pingers to be able to hit vehicles properly;
            // cylinders don't work - Calypto
            LinkMesh(Tracked.Mesh);
        }
        // for weapon pawn, we need the vehicle's collision radius, not the turret
        if(ONSWeaponPawn(Tracked) != None)
        {
            // Check if the VehicleBase actually exists before accessing its properties
            if (ONSWeaponPawn(Tracked).VehicleBase != None)
            {
                SetCollisionSize(
                    ONSWeaponPawn(Tracked).VehicleBase.CollisionRadius,
                    ONSWeaponPawn(Tracked).VehicleBase.CollisionHeight);
            }
            else
            {
                // Fallback to the turret's own collision if VehicleBase is missing
                SetCollisionSize(Tracked.CollisionRadius, Tracked.CollisionHeight);
            }
        }
    }
    else
    {
        SetCollisionSize(Tracked.CollisionRadius, Tracked.CollisionHeight);
    }
}

function GoToPawn()
{
    if (Tracked != None)
    {
        SetLocation(Tracked.Location);
        SetCollisionSize(Tracked.CollisionRadius, Tracked.CollisionHeight);
        if (bUseCylinderCollision)
        {
            if (!bCrouched && Tracked.bIsCrouched)
            {
                SetCollisionSize(CrouchRadius, CrouchHeight);
                bCrouched = true;
            }
            else if (bCrouched && !Tracked.bIsCrouched)
            {
                SetCollisionSize(DefaultCollisionRadius, DefaultCollisionHeight);
                bCrouched = false;
            }
        }
        SetCollision(true);
    }
}

function Rewind(float DeltaTime)
{
    local float TargetTimestamp;
    local float Alpha;
    local int Lo;
    local int Up;

    if (Tracked == None || Tracked.DrivenVehicle != None)
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
        else if (Tracked.IsA('xPawn'))
        {
            SetCollisionSize(DefaultCollisionRadius, DefaultCollisionHeight);
        }
        else if (bUseCylinderCollision)
        {
            SetCollisionSize(Tracked.CollisionRadius, Tracked.CollisionHeight);
        }
        SetLocation(Snapshots[Lo].Location);
        SetRotation(Snapshots[Lo].Rotation);
    }
    // More comments from WSUTComp:
    // Without LinkMesh enabled, this logic will not let you hit the vehicle if the main seat is
    // occupied (if gunner then works fine) - Calypto
    // Do not enable collision for passenger seats to prevent the phantom cylinder shield
    // A vehicle attached to another vehicle is a passenger seat
    if (Tracked.bCollideActors
        && (!Tracked.IsA('Vehicle') || Tracked.Base == None || !Tracked.Base.IsA('Vehicle')))
    {
        // Enable collision for infantry and main vehicles
        SetCollision(true);
    }
}

function UndoRewind()
{
    SetCollision(false);
}

event TakeDamage(int Damage,
                 Pawn EventInstigator,
                 Vector HitLocation,
                 Vector Momentum,
                 class<DamageType> DamageType)
{
    // TODO: could some code be simplified by redirecting damage to Pawn here?
    Warn("Pawn tracker should never take damage");
}

event Destroyed()
{
    LinkMesh(None);
    Super.Destroyed();
}

function Tick(float DeltaTime)
{
    local float OldestTimestamp;
    local int i;

    if (Tracked != None)
    {
        OldestTimestamp = Level.TimeSeconds - HexedNET.GetCompensationLimit();
        while (Snapshots.Length > 0 && Snapshots[0].Timestamp < OldestTimestamp)
        {
            Snapshots.Remove(0, 1);
        }
        i = Snapshots.Length;
        Snapshots.Length = i + 1;
        Snapshots[i].Timestamp = Level.TimeSeconds;
        Snapshots[i].Location = Tracked.Location;
        Snapshots[i].Rotation = Tracked.Rotation;
        Snapshots[i].bCrouched = Tracked.bIsCrouched;
    }
}

// TODO: what about self-inflicted splash damage if target is close?
// By updating to collide in the current target location (instead of past location),
// players might wrongfully avoid self-inflicted splash damage.
final function Vector GetPresentHitLocation(Vector HitLocation)
{
    // TODO: handle crouching differences
    return HitLocation + Tracked.Location - Location;
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
}
