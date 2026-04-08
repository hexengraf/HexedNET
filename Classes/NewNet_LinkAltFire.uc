class NewNet_LinkAltFire extends LinkAltFire;

const PROJ_TIMESTEP = 0.0201;
const MAX_PROJECTILE_FUDGE = 0.075;
const SLACK = 0.025;

var class<Projectile> FakeProjectileClass;
var FakeProjectileManager FPM;

var vector OldInstigatorLocation;
var Vector OldInstigatorEyePosition;
var vector OldXAxis,OldYAxis, OldZAxis;
var rotator OldAim;

#include Classes\Include\WeaponFireBase.uci

function Projectile SpawnProjectile(Vector Start, Rotator Dir)
{
    local LinkProjectile Proj;
    local vector HitLocation, HitNormal, End;
    local actor Other;
    local float f,g;

    if (class'HxNTClient'.static.IsEnhancedNetcodeEnabled(Level))
    {
        return SpawnFakeProjectile(Start, Dir);
    }
    if (!bUseEnhancedNetCode)
    {
       return Super.SpawnProjectile(Start, Dir);
    }
    Start += Vector(Dir) * 10.0 * LinkGun(Weapon).Links;
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
       }

       if(Other == none)
           Proj = Weapon.Spawn(class'NewNet_LinkProjectile',,, End, Dir);
       else
       {
           Proj = Weapon.Spawn(class'NewNet_LinkProjectile',,, HitLocation - Vector(dir)*20.0, Dir);
       }
    }
    else
        Proj = Weapon.Spawn(class'NewNet_LinkProjectile',,, Start, Dir);
    if ( Proj != None )
    {
		Proj.Links = LinkGun(Weapon).Links;
		Proj.LinkAdjust();
	}
	if(NewNet_LinkProjectile(proj)!=None)
    {
        NewNet_LinkProjectile(proj).Index=NewNet_LinkGun(Weapon).CurIndex;
        NewNet_LinkGun(Weapon).CurIndex++;
    }

    return Proj;
}

function vector Extrapolate(out rotator Dir, float dF)
{
    return vector(Dir)*ProjectileClass.default.speed*dF;
}

function CheckFireEffect()
{
   if(Level.NetMode == NM_Client && Instigator.IsLocallyControlled())
   {
       if(class'HxNTClient'.default.PredictedPing - SLACK > MAX_PROJECTILE_FUDGE)
       {
           OldInstigatorLocation = Instigator.Location;
           OldInstigatorEyePosition = Instigator.EyePosition();
           Weapon.GetViewAxes(OldXAxis,OldYAxis,OldZAxis);
           OldAim=AdjustAim(OldInstigatorLocation+OldInstigatorEyePosition, AimError);
           SetTimer(class'HxNTClient'.default.PredictedPing - SLACK - MAX_PROJECTILE_FUDGE, false);
       }
       else
           DoClientFireEffect();
   }
}

function Timer()
{
   DoTimedClientFireEffect();
}

function PlayFiring()
{
    Super.PlayFiring();
    if (class'HxNTClient'.static.IsEnhancedNetcodeEnabled(Level))
    {
        CheckFireEffect();
    }
}

function DoClientFireEffect()
{
   super.DoFireEffect();
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
   // Weapon.GetViewAxes(X,Y,Z);
    X = OldXaxis;
    Y = OldXaxis;
    Z = OldXaxis;

  //  StartTrace = Instigator.Location + Instigator.EyePosition();// + X*Instigator.CollisionRadius;
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
            R.Yaw = Spread * (FRand()-0.5);
            R.Pitch = Spread * (FRand()-0.5);
            R.Roll = Spread * (FRand()-0.5);
            SpawnFakeProjectile(StartProj, Rotator(X >> R));
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

    if(FPM==None)
        FindFPM();

    if(FPM.AllowFakeProjectile(FakeProjectileClass, NewNet_LinkGun(Weapon).CurIndex) && class'HxNTClient'.default.predictedping >= 0.050)
    {
        p = Spawn(FakeProjectileClass,Weapon.Owner,, Start, Dir);
    }
    if( p == none )
        return None;
    FPM.RegisterFakeProjectile(p, NewNet_LinkGun(Weapon).CurIndex);
    return p;
}

simulated function FindFPM()
{
    foreach Weapon.DynamicActors(class'FakeProjectileManager', FPM)
        break;
}


DefaultProperties
{
    FakeProjectileClass=class'NewNet_Fake_LinkProjectile'
    ProjectileClass=class'NewNet_LinkProjectile'
}
