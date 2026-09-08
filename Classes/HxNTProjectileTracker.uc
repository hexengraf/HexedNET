class HxNTProjectileTracker extends Actor;

struct HxRoutePoint
{
    var Vector Location;
    var Vector Velocity;
    var float Radius;
    var float Timestamp;
};

var private Projectile Tracked;
var private array<HxRoutePoint> RoutePoints;

function SetTracked(Projectile P)
{
    Tracked = P;
    StoreRoutePoint();
}

// TODO: maybe move tracked to past location instead of using current location?
function Projectile GetTracked(out Vector HitLocation)
{
    if (Tracked != None)
    {
        HitLocation = HitLocation + (Tracked.Location - Location);
    }
    return Tracked;
}

function StoreRoutePoint()
{
    local HxRoutePoint Point;

    Point.Location = Tracked.Location;
    Point.Velocity = Tracked.Velocity;
    Point.Radius = Tracked.CollisionRadius;
    Point.Timestamp = Level.TimeSeconds;
    RoutePoints[RoutePoints.Length] = Point;
}

function Rewind(float DeltaTime)
{
    local int Index;

    Index = FindLowerBound(Level.TimeSeconds - DeltaTime);
    DeltaTime = FMax(0, (Level.TimeSeconds - RoutePoints[Index].Timestamp) - DeltaTime);
    SetLocation(RoutePoints[Index].Location + RoutePoints[Index].Velocity * DeltaTime);
    SetCollisionSize(RoutePoints[Index].Radius, RoutePoints[Index].Radius);
    SetCollision(true);
}

function UndoRewind()
{
    SetCollision(false);
}

event Destroyed()
{
    if (MutHexedNET(Owner) != None)
    {
        MutHexedNET(Owner).RemoveProjectileTracker(Self);
    }
    Super.Destroyed();
}

final function int FindLowerBound(float Timestamp)
{
    local int Result;
    local int Middle;
    local int Low;
    local int High;

    Result = 0;
    Low = 0;
    if (RoutePoints[Low].Timestamp <= Timestamp)
    {
        High = RoutePoints.Length - 1;
        while (Low <= High)
        {
            Middle = (Low + High) / 2;
            if (RoutePoints[Middle].Timestamp > Timestamp)
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
}
