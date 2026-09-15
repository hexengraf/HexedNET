class HxNet_RocketProj extends RocketProj;

var HxNTClient Client;
var int Index;
var private Vector InterpolationOffset;
var private float InterpolationPeriod;
var private bool bInterpolate;
var private int TickCount;

replication
{
    unreliable if (bDemoRecording)
        DoMove, DoSetLocation;

    reliable if (Role == ROLE_Authority && bNetInitial)
        Client, Index;
}

simulated function PostNetBeginPlay()
{
    local PlayerController PC;

    Super(Projectile).PostNetBeginPlay();
    if (Level.NetMode == NM_Client && Client != None && Client.WantsPingCompensation())
    {
        SearchPredictedProjectile();
    }
    if (FlockIndex != 0)
    {
        SetTimer(0.1, true);
        PopulateFlock();
    }
    if (Level.NetMode != NM_DedicatedServer)
    {
        if (Level.bDropDetail || Level.DetailMode == DM_Low)
        {
            bDynamicLight = false;
            LightType = LT_None;
        }
        else
        {
            PC = Level.GetLocalPlayerController();
            if ((Instigator == None || PC != Instigator.Controller)
                && (PC == None || PC.ViewTarget == None
                    || VSize(PC.ViewTarget.Location - Location) > 3000))
            {
                bDynamicLight = false;
                LightType = LT_None;
            }
        }
    }
}

simulated function SearchPredictedProjectile()
{
    local HxNTWeaponInfo WeaponInfo;
    local RocketProj Rocket;

    WeaponInfo = Client.GetWeaponInfo(class'RocketLauncher');
    Rocket = RocketProj(WeaponInfo.MatchProjectileFull(
        Location, class'HxNet_RocketProjPredicted', Index));
    if (Rocket != None)
    {
        InterpolatePredicted(Rocket);
        Rocket.Destroy();
    }
}

simulated function InterpolatePredicted(RocketProj Predicted)
{
    if (Predicted != None)
    {
        ApplyPredictedEffects(Self, Predicted);
        bInterpolate = true;
        InterpolationOffset = Location - Predicted.Location;
        DoSetLocation(Predicted.Location);
    }
}

simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    if (TickCount < 2)
    {
        ++TickCount;
    }
    if (bInterpolate)
    {
        DeltaTime = FMin(DeltaTime, InterpolationPeriod);
        if (DeltaTime > 0)
        {
            DoMove(InterpolationOffset * DeltaTime / default.InterpolationPeriod);
            InterpolationPeriod -= DeltaTime;
        }
        bInterpolate = InterpolationPeriod > 0;
    }
}

simulated function Explode(Vector HitLocation, Vector HitNormal)
{
    local HxNet_RocketProjEffects Effects;

    if (Role == ROLE_Authority && TickCount < 2)
    {
        Effects = Spawn(class'HxNet_RocketProjEffects',,, Location, Rotation);
        Effects.HitLocation = HitLocation;
        Effects.HitNormal = HitNormal;
        BlowUp(HitLocation);
        Destroy();
    }
    else
    {
        Super.Explode(HitLocation, HitNormal);
    }
}

simulated function DoMove(Vector Offset)
{
    Move(Offset);
}

simulated function DoSetLocation(Vector NewLocation)
{
    SetLocation(NewLocation);
}

simulated function PopulateFlock()
{
    local HxNet_RocketProj R;
    local int i;

    if (Flock[1] == None)
    {
        foreach DynamicActors(class'HxNet_RocketProj', R)
        {
            if (R != Self && R.FlockIndex == Self.FlockIndex)
            {
                SetDeterministicFlock(R);
                R.SetDeterministicFlock(Self);
                ++i;
                if (i == 2)
                {
                    break;
                }
            }
        }
    }
}

simulated function SetDeterministicFlock(HxNet_RocketProj P)
{
    switch (Index)
    {
        case 0:
            Flock[P.Index - 1] = P;
            break;
        case 1:
            Flock[Max(0, P.Index - 1)] = P;
            break;
        case 2:
            Flock[P.Index] = P;
            break;
    }
}

static function ApplyPredictedEffects(RocketProj P, RocketProj Predicted)
{
    if (P.SmokeTrail != None)
    {
        P.SmokeTrail.mRegen = false;
    }
    if (Predicted.SmokeTrail != None)
    {
        P.SmokeTrail = Predicted.SmokeTrail;
        P.SmokeTrail.SetOwner(P);
        Predicted.SmokeTrail = None;
    }
    if (P.Corona != None)
    {
        P.Corona.Destroy();
    }
    if (Predicted.Corona != None)
    {
        P.Corona = Predicted.Corona;
        P.Corona.SetOwner(P);
        Predicted.Corona = None;
    }
}

static function RemoveFromFlock(RocketProj P)
{
    local int i;
    local int j;

    for (i = 0; i < ArrayCount(P.Flock); ++i)
    {
        if (P.Flock[i] != None)
        {
            for (j = 0; j < ArrayCount(P.Flock); ++j)
            {
                if (P.Flock[i].Flock[j] == P)
                {
                    P.Flock[i].Flock[j] = None;
                }
            }
        }
    }
}

defaultproperties
{
    InterpolationPeriod=0.30
}
