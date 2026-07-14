class NewNet_BioChargedFire extends BioChargedFire;

const PROJ_TIMESTEP = 0.0201;
const MAX_PROJECTILE_FUDGE = 0.075;

var private MutHexedNET HexedNET;
var private HxNTClient Client;

function PreBeginPlay()
{
    Super.PreBeginPlay();
    foreach Weapon.DynamicActors(class'MutHexedNET', HexedNET) break;
    class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client);
}

function bool IsEnhancedNetcodeEnabled()
{
    return class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        && Client.IsEnhancedNetcodeEnabled();
}

function projectile SpawnProjectile(Vector Start, Rotator Dir)
{
    local rotator NewDir,outDir;
    local float f,g;
    local vector End, HitLocation, HitNormal, VZ;
    local actor Other;
    local BioGlob Glob;
    local float PingDT;

    GotoState('');

    if (GoopLoad == 0) return None;

    if (Level.NetMode == NM_Client || !IsEnhancedNetcodeEnabled())
    {
        return Super.SpawnProjectile(start,Dir);
    }
    PingDT = FMin(Client.AveragePing, MAX_PROJECTILE_FUDGE);
    if( class'BioGlob' != none )
    {
        if(PingDT > 0.0 && Weapon.Owner!=None)
        {
            OutDir=Dir;
            for(f=0.00; f<pingDT + PROJ_TIMESTEP; f+=PROJ_TIMESTEP)
            {
                //Make sure the last trace we do is right where we want
                //the proj to spawn if it makes it to the end
                g = Fmin(pingdt, f);
                //Where will it be after deltaF, NewDir byRef for next tick
                 End = Start + NewExtrapolate(Dir, g, outDir, GoopLoad);
              /*  if(f > pingDT)
                   End = Start + Extrapolate(Dir, (pingDT-f+PROJ_TIMESTEP),GoopLoad);
                else
                   End = Start + Extrapolate(Dir, PROJ_TIMESTEP,GoopLoad);
              */
                //Put pawns there
                HexedNET.TimeTravel(pingdt - g);
                //Trace between the start and extrapolated end
                Other = HexedNET.TimeTravelTrace(Weapon, HitLocation, HitNormal, End, Start);
                if(Other!=None)
                {
                    break;
                }
                //repeat
               // Start=End;
           }
           HexedNET.UnTimeTravel();

           if(Other!=None && Other.IsA('PawnCollisionCopy'))
           {
                 HitLocation = HitLocation + PawnCollisionCopy(Other).CopiedPawn.Location - Other.Location;
                 Other=PawnCollisionCopy(Other).CopiedPawn;
           }

           VZ.Z = class'BioGlob'.default.TossZ;
           NewDir =  rotator(vector(OutDir)*class'BioGlob'.default.speed - VZ);
           if(Other == none)
               glob = Weapon.Spawn(class'NewNet_BioGlob',,, End, NewDir);
           else
           {
               glob = Weapon.Spawn(class'NewNet_BioGlob',,, HitLocation - Vector(Newdir)*16.0, NewDir);
           }
        }
        else
            glob = Weapon.Spawn(class'NewNet_BioGlob',,, Start, Dir);
    }

    if ( Glob != None )
    {
		Glob.Damage *= DamageAtten;
		Glob.SetGoopLevel(GoopLoad);
		Glob.AdjustSpeed();
    }
    GoopLoad = 0;
    if ( Weapon.AmmoAmount(ThisModeNum) <= 0 )
        Weapon.OutOfAmmo();
    return Glob;
}

function vector NewExtrapolate(rotator Dir, float dF, out rotator outDir, byte GoopLoad)
{
    local vector V;
    local vector Pos;
    local float GooSpeed;

   // if(vSize(vector(Dir)) != 1.0)
   //    log(vSize(vector(Dir)));

    if ( GoopLoad < 1 )
	    GooSpeed =  class'BioGlob'.default.speed;
	else
	    GooSpeed =  class'BioGlob'.default.speed * (0.4 + GoopLoad)/(1.4*GoopLoad);

    V = vector(Dir)*GooSpeed;
    V.Z += ProjectileClass.default.TossZ;

    Pos = V*dF + 0.5*square(dF)*Weapon.Owner.PhysicsVolume.Gravity;
    OutDir = rotator(V + dF*Weapon.Owner.PhysicsVolume.Gravity);
    return Pos;
}

function vector Extrapolate(out rotator Dir, float dF, byte GoopLoad)
{
    local rotator OldDir;
    local float GooSpeed;

    OldDir = Dir;

    if ( GoopLoad < 1 )
	    GooSpeed =  class'BioGlob'.default.speed;
	else
	    GooSpeed =  class'BioGlob'.default.speed * (0.4 + GoopLoad)/(1.4*GoopLoad);

    Dir = rotator(vector(OldDir)*Goospeed + Weapon.Owner.PhysicsVolume.Gravity*dF);

    return vector(OldDir)*Goospeed*dF + 0.5*Square(dF)*Weapon.Owner.PhysicsVolume.Gravity;
}

DefaultProperties
{
}
