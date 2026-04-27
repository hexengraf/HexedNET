class NewNet_FlakFire extends FlakFire;

var bool bUseReplicatedInfo;
var rotator savedRot;
var vector savedVec;

var vector OldInstigatorLocation;
var Vector OldInstigatorEyePosition;
var vector OldXAxis,OldYAxis, OldZAxis;
var rotator OldAim;

var class<Projectile> FakeProjectileClass;
var FakeProjectileManager FPM;
var MutHexedNET MNN;
var bool bSkipNextEffect;

const PROJ_TIMESTEP = 0.0251;
const MAX_PROJECTILE_FUDGE = 0.075;
const SLACK = 0.035;

#include Classes\Include\WeaponFireBase.uci

function PlayFiring()
{
    Super.PlayFiring();
    if (class'HxNTClient'.static.IsEnhancedNetcodeEnabled(Level))
    {
        if (bSkipNextEffect)
        {
            bSkipNextEffect = false;
            Weapon.ClientStopFire(0);
        }
        else
        {
            CheckFireEffect();
        }
    }
}

function CheckFireEffect()
{
   if(Level.NetMode == NM_Client && Instigator.IsLocallyControlled())
   {
       if (class'HxNTClient'.default.AveragePing - SLACK > MAX_PROJECTILE_FUDGE)
       {
           OldInstigatorLocation = Instigator.Location;
           OldInstigatorEyePosition = Instigator.EyePosition();
           Weapon.GetViewAxes(OldXAxis,OldYAxis,OldZAxis);
           OldAim=AdjustAim(OldInstigatorLocation+OldInstigatorEyePosition, AimError);
           SetTimer(class'HxNTClient'.default.AveragePing - SLACK - MAX_PROJECTILE_FUDGE, false);
       }
       else
           DoClientFireEffect();
   }
}

function Timer()
{
   DoTimedClientFireEffect();
}

function DoInstantFireEffect()
{
   CheckFireEffect();
   bSkipNextEffect=true;
}

simulated function DoTimedClientFireEffect()
{
    local Vector StartProj, StartTrace, X,Y,Z;
    local Rotator R, Aim;
    local Vector HitLocation, HitNormal;
    local Actor Other;
    local int p;
    local int SpawnCount;
    local float theta;

    Instigator.MakeNoise(1.0);
    //Weapon.GetViewAxes(X,Y,Z);
    X = OldXAxis;
    Y = OldXAxis;
    Z = OldXAxis;

   // StartTrace = Instigator.Location + Instigator.EyePosition();// + X*Instigator.CollisionRadius;
    StartTrace = OldInstigatorLocation + OldInstigatorEyePosition;

   StartProj = StartTrace + X*ProjSpawnOffset.X;
    if ( !Weapon.WeaponCentered() )
	    StartProj = StartProj + Weapon.Hand * Y*ProjSpawnOffset.Y + Z*ProjSpawnOffset.Z;

    // check if projectile would spawn through a wall and adjust start location accordingly
    Other = Weapon.Trace(HitLocation, HitNormal, StartProj, StartTrace, false);
    if (Other != None)
    {
        StartProj = HitLocation;
    }

   // Aim = AdjustAim(StartProj, AimError);
     Aim = OldAim;
    SpawnCount = Max(1, ProjPerFire * int(Load));

    switch (SpreadStyle)
    {
    case SS_Random:
        X = Vector(Aim);
        for (p = 0; p < SpawnCount; p++)
        {
            R = NewNet_FlakCannon(Weapon).GetRandRot();
            if(FPM==None)
                FindFPM();
            if(FPM.AllowFakeProjectile(FakeProjectileClass, p))
            {
                FPM.RegisterFakeProjectile(FlakChunk(SpawnFakeProjectile(StartProj, Rotator(X >> R))), p);
            }
        }
        break;
    case SS_Line:
        for (p = 0; p < SpawnCount; p++)
        {
            theta = Spread*PI/32768*(p - float(SpawnCount-1)/2.0);
            X.X = Cos(theta);
            X.Y = Sin(theta);
            X.Z = 0.0;
            SpawnFakeProjectile(StartProj, Rotator(X >> Aim));
        }
        break;
    default:
        SpawnFakeProjectile(StartProj, Aim);
    }
}

simulated function DoClientFireEffect()
{
    local Vector StartProj, StartTrace, X,Y,Z;
    local Rotator R, Aim;
    local Vector HitLocation, HitNormal;
    local Actor Other;
    local int p;
    local int SpawnCount;
    local float theta;

    Instigator.MakeNoise(1.0);
    Weapon.GetViewAxes(X,Y,Z);

    StartTrace = Instigator.Location + Instigator.EyePosition();// + X*Instigator.CollisionRadius;
    StartProj = StartTrace + X*ProjSpawnOffset.X;
    if ( !Weapon.WeaponCentered() )
	    StartProj = StartProj + Weapon.Hand * Y*ProjSpawnOffset.Y + Z*ProjSpawnOffset.Z;

    // check if projectile would spawn through a wall and adjust start location accordingly
    Other = Weapon.Trace(HitLocation, HitNormal, StartProj, StartTrace, false);
    if (Other != None)
    {
        StartProj = HitLocation;
    }

    Aim = AdjustAim(StartProj, AimError);

    SpawnCount = Max(1, ProjPerFire * int(Load));

    switch (SpreadStyle)
    {
    case SS_Random:
        X = Vector(Aim);
        for (p = 0; p < SpawnCount; p++)
        {
            R = NewNet_FlakCannon(Weapon).GetRandRot();
            if(FPM==None)
                FindFPM();
            if(FPM.AllowFakeProjectile(FakeProjectileClass, p))
                FPM.RegisterFakeProjectile(FlakChunk(SpawnFakeProjectile(StartProj, Rotator(X >> R))), p);
        }
        break;
    case SS_Line:
        for (p = 0; p < SpawnCount; p++)
        {
            theta = Spread*PI/32768*(p - float(SpawnCount-1)/2.0);
            X.X = Cos(theta);
            X.Y = Sin(theta);
            X.Z = 0.0;
            SpawnFakeProjectile(StartProj, Rotator(X >> Aim));
        }
        break;
    default:
        SpawnFakeProjectile(StartProj, Aim);
    }
}


simulated function projectile SpawnFakeProjectile(Vector Start, Rotator Dir)
{
    local Projectile p;

    p = FakeSuperSpawnProjectile(Start,Dir);
	return p;
}

simulated function projectile FakeSuperSpawnProjectile(Vector Start, Rotator Dir)
{
    local Projectile p;

    if( ProjectileClass != None )
        p = Weapon.Spawn(FakeProjectileClass,,, Start, Dir);

    if( p == none )
        return None;
    p.Damage *= DamageAtten;
    return p;
}

simulated function FindFPM()
{
    foreach Weapon.DynamicActors(class'FakeProjectileManager', FPM)
        break;
}

function DoFireEffect()
{
    local Vector StartProj, StartTrace, X,Y,Z;
    local Rotator R, Aim;
    local Vector HitLocation, HitNormal;
    local Actor Other;
    local int p;
    local int SpawnCount;
    local float theta;
    local projectile proj;

    if(!bUseEnhancedNetCode)
    {
       super.DoFireEffect();
       return;
    }

    Instigator.MakeNoise(1.0);
    Weapon.GetViewAxes(X,Y,Z);

    if(bUseReplicatedInfo)
        StartTrace = SavedVec;
    else
        StartTrace = Instigator.Location + Instigator.EyePosition();// + X*Instigator.CollisionRadius;

    StartProj = StartTrace + X*ProjSpawnOffset.X;
    if ( !Weapon.WeaponCentered() )
	    StartProj = StartProj + Weapon.Hand * Y*ProjSpawnOffset.Y + Z*ProjSpawnOffset.Z;

    // check if projectile would spawn through a wall and adjust start location accordingly
    if(Weapon.Owner!=None)
        Other = Weapon.Owner.Trace(HitLocation, HitNormal, StartProj, StartTrace, false);
    else
        Other=Weapon.Trace(HitLocation, HitNormal, StartProj, StartTrace, false);
    if (Other != None)
    {
        StartProj = HitLocation;
    }

    if(bUseReplicatedInfo)
    {
        Aim = SavedRot;
        bUseReplicatedInfo=false;
    }
    else
        Aim = AdjustAim(StartProj, AimError);

    SpawnCount = Max(1, ProjPerFire * int(Load));

    switch (SpreadStyle)
    {
    case SS_Random:
        X = Vector(Aim);
        for (p = 0; p < SpawnCount; p++)
        {
            R = NewNet_FlakCannon(Weapon).GetRandRot();
            proj = SpawnProjectile(StartProj, Rotator(X >> R));
            if(proj!=None)
                NewNet_FlakChunk(proj).ChunkNum = p;
        }
        break;
    case SS_Line:
        for (p = 0; p < SpawnCount; p++)
        {
            theta = Spread*PI/32768*(p - float(SpawnCount-1)/2.0);
            X.X = Cos(theta);
            X.Y = Sin(theta);
            X.Z = 0.0;
            SpawnProjectile(StartProj, Rotator(X >> Aim));
        }
        break;
    default:
        SpawnProjectile(StartProj, Aim);
    }
    NewNet_FlakCannon(Weapon).SendNewRandSeed();
}

function projectile SpawnProjectile(Vector Start, Rotator Dir)
{
    local Projectile p;

    local vector End, HitNormal, HitLocation;
    local actor Other;
    local float f,g;
    local vector originalStart;

    originalStart = start;

    if(!bUseEnhancedNetCode)
        return super.SpawnProjectile(Start,Dir);
    /* change this to use gravity */
    if( ProjectileClass != None )
    {
        if(PingDT > 0.0 && Weapon.Owner!=None)
        {
            Start-=1.0*vector(Dir);
            for(f=0.00; f<pingDT + PROJ_TIMESTEP; f+=PROJ_TIMESTEP)
            {
                //Make sure the last trace we do is right where we want
                //the proj to spawn if it makes it to the end
                g = Fmin(pingdt, f);

                //Where will it be after deltaF, Dir byRef for next tick
                if(f >= pingDT)
                    End = Start + Extrapolate(Dir, (pingDT-f+PROJ_TIMESTEP));
                else
                    End = Start + Extrapolate(Dir, PROJ_TIMESTEP);

                //Put pawns there
                HexedNET.TimeTravel(pingdt - g);
                //RadiusTimeTravel(pingDT-g);
                //Trace between the start and extrapolated end
                Other = HexedNET.TimeTravelTrace(Weapon, HitLocation, HitNormal, End, Start);
                if(Other!=None)
                {
                    break;
                }
                //repeat
                Start=End;
           }
           HexedNET.UnTimeTravel();

           if(Other!=None && Other.IsA('PawnCollisionCopy'))
           {
               HitLocation = HitLocation + PawnCollisionCopy(Other).CopiedPawn.Location - Other.Location;
               Other=PawnCollisionCopy(Other).CopiedPawn;
               p = Weapon.Spawn(ProjectileClass,,, HitLocation - Vector(dir)*20.0, Dir);
           }
           else
           {
               p = Weapon.Spawn(ProjectileClass,,, originalStart, Dir);
           }
        }
        else
        {
            p = Weapon.Spawn(ProjectileClass,,, Start, Dir);
        }
    }

    if( p == None )
        return None;

    p.Damage *= DamageAtten;
    return p;
}

function vector Extrapolate(out rotator Dir, float dF)
{
    return vector(Dir)*ProjectileClass.default.speed*dF;
}

defaultproperties
{
    FakeProjectileClass=Class'NewNet_Fake_FlakChunk'
    ProjectileClass=Class'NewNet_FlakChunk'
}
