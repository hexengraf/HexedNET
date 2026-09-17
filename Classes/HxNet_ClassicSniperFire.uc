class HxNet_ClassicSniperFire extends ClassicSniperFire
    DependsOn(HxNTWeapon);

var float ServerDelay;
var private MutHexedNET HexedNET;
var private HxNTClient Client;
var private Vector BASStart;
var private Rotator BASAim;
var private bool bBoostedAimSynchronization;

function PreBeginPlay()
{
    Super.PreBeginPlay();
    class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client);
}

function bool WantsPingCompensation()
{
    return class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        && Client.WantsPingCompensation();
}

function ApplyBAS(HxNTWeapon.HxBAS BAS)
{
    if (class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client))
    {
        class'HxNTWeapon'.static.DecodeBAS(BAS, BASStart, BASAim);
        bBoostedAimSynchronization = Client.IsAcceptableBAS(Weapon, BASStart, BASAim);
    }
}

function DoFireEffect()
{
    if (bBoostedAimSynchronization)
    {
        Instigator.MakeNoise(1.0);
        DoTrace(BASStart, BASAim);
        bBoostedAimSynchronization = false;
    }
    else
    {
        Super.DoFireEffect();
    }
    ServerDelay = 0;
}

function DoTrace(Vector Start, Rotator Dir)
{
    local Actor Other;
    local Pawn HeadShotPawn;
    local SniperWallHitEffect S;
    local Vector X;
    local Vector End;
    local Vector HitLocation;
    local Vector HitNormal;

    if (Level.NetMode == NM_Client || !WantsPingCompensation())
    {
        Super.DoTrace(Start,Dir);
        return;
    }
    X = Vector(Dir);
    End = Start + TraceRange * X;
    HexedNET.Rewind(Client.GetCompensationTime() + ServerDelay);
    Other = HexedNET.RewoundTrace(Weapon, HitLocation, HitNormal, End, Start);
    HexedNET.UndoRewind();
    if (Level.NetMode != NM_Standalone || PlayerController(Instigator.Controller) == None)
    {
        Weapon.Spawn(class'TracerProjectile', Instigator.Controller,, Start, Dir);
    }
    if (Other != None && Other != Instigator)
    {
        if (!Other.bWorldGeometry)
        {
            if (Vehicle(Other) != None)
            {
                HeadShotPawn = Vehicle(Other).CheckForHeadShot(HitLocation, X, 1.0);
            }
            if (HeadShotPawn != None)
            {
                HeadShotPawn.TakeDamage(
                    DamageMax * HeadShotDamageMult,
                    Instigator,
                    HitLocation,
                    Momentum * X,
                    DamageTypeHeadShot);
            }
            else if (Pawn(Other) != None && Pawn(Other).IsHeadShot(HitLocation, X, 1.0))
            {
                Other.TakeDamage(
                    DamageMax * HeadShotDamageMult,
                    Instigator,
                    HitLocation,
                    Momentum * X,
                    DamageTypeHeadShot);
            }
            else
            {
                Other.TakeDamage(
                    DamageMax, Instigator, HitLocation, Momentum * X, DamageType);
            }
        }
        else
        {
            HitLocation = HitLocation + 2.0 * HitNormal;
        }
    }
    else
    {
        HitLocation = End;
        HitNormal = Normal(Start - End);
    }
    if (HitNormal != Vect(0, 0, 0) && HitScanBlockingVolume(Other) == None)
    {
        S = Weapon.Spawn(class'SniperWallHitEffect',,, HitLocation, Rotator(-1 * HitNormal));
        if (S != None)
        {
            S.FireStart = Start;
        }
    }
}

defaultproperties
{
}
