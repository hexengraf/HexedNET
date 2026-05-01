class NewNet_RocketLauncher extends RocketLauncher
    HideDropDown
	CacheExempt;

const MAX_PROJECTILE_FUDGE = 0.275;
const MAX_PROJECTILE_FUDGE_ALT = 0.275;
const PROJ_TIMESTEP = 0.0201;

struct ReplicatedRotator
{
    var int Yaw;
    var int Pitch;
};

struct ReplicatedVector
{
    var float X;
    var float Y;
    var float Z;
};

var MutHexedNET HexedNET;
var private HxNTClient Client;
var private HxNTClock NETClock;
var private const class<Weapon> BaseClass;
var private bool bConfigCleared;

var float lastDT;

replication
{
    reliable if(Role < Role_Authority)
        NewNet_ServerStartFire;
}

event PreBeginPlay()
{
    Super.PreBeginPlay();
    ForEach DynamicActors(class'MutHexedNET', HexedNET) break;
    ValidateClient();
}

#include Classes\Include\WeaponBaseFunctions.uci

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    if (Level.NetMode != NM_DedicatedServer)
    {
        ForceBaseClassConfig();
    }
}

simulated event NewNet_ClientStartFire(int Mode)
{
    local ReplicatedRotator R;
    local ReplicatedVector V;
    local vector Start;
	local int OtherMode;

    if (!ValidateClient())
    {
        Super.ClientStartFire(Mode);
        return;
    }
	if ( RocketMultiFire(FireMode[Mode]) != None )
	{
		SetTightSpread(false);
	}
    else
    {
		if ( Mode == 0 )
			OtherMode = 1;
		else
			OtherMode = 0;

		if ( FireMode[OtherMode].bIsFiring || (FireMode[OtherMode].NextFireTime > Level.TimeSeconds) )
		{
			if ( FireMode[OtherMode].Load > 0 )
				SetTightSpread(true);
			if ( bDebugging )
				log("No RL reg fire because other firing "$FireMode[OtherMode].bIsFiring$" next fire "$(FireMode[OtherMode].NextFireTime - Level.TimeSeconds));
			return;
		}
	}
    if (Role < ROLE_Authority)
    {
        if (StartFire(Mode))
        {
         /*   if(NewNet_RocketMultiFire(FireMode[Mode])!=None)
                NewNet_RocketMultiFire(FireMode[Mode]).DoInstantFireEffect();
            else*/ if(NewNet_RocketFire(FireMode[Mode])!=None)
                NewNet_RocketFire(FireMode[Mode]).DoInstantFireEffect();
            R.Pitch = Pawn(Owner).Controller.Rotation.Pitch;
            R.Yaw = Pawn(Owner).Controller.Rotation.Yaw;
            STart=Pawn(Owner).Location + Pawn(Owner).EyePosition();

            V.X = Start.X;
            V.Y = Start.Y;
            V.Z = Start.Z;

            NewNet_ServerStartFire(mode, R, V);
        }
    }
    else
    {
        StartFire(Mode);
    }
}

function NewNet_ServerStartFire(byte Mode, ReplicatedRotator R, ReplicatedVector V)
{
    if (!ServerShouldStartFire())
    {
        return;
    }
    // if(NewNet_RocketFire(FireMode[Mode])!=None)
    // {
    //    NewNet_RocketFire(FireMode[Mode]).PingDT = FMin(Ping + 1.75*NETClock.AverDT, MAX_PROJECTILE_FUDGE_ALT);
    // }
    // else if(NewNet_RocketMultiFire(FireMode[Mode])!=None)
    // {
    //    NewNet_RocketMultiFire(FireMode[Mode]).PingDT = FMin(Ping + 1.75*NETClock.AverDT, MAX_PROJECTILE_FUDGE);
    // }

    if ( (FireMode[Mode].NextFireTime <= Level.TimeSeconds + FireMode[Mode].PreFireTime)
		&& StartFire(Mode) )
    {
        FireMode[Mode].ServerStartFireTime = Level.TimeSeconds;
        FireMode[Mode].bServerDelayStartFire = false;

        if(NewNet_RocketFire(FireMode[Mode])!=None)
        {
            ValidateNETClockPointer();
            NewNet_RocketFire(FireMode[Mode]).SavedVec.X = V.X;
            NewNet_RocketFire(FireMode[Mode]).SavedVec.Y = V.Y;
            NewNet_RocketFire(FireMode[Mode]).SavedVec.Z = V.Z;
            NewNet_RocketFire(FireMode[Mode]).SavedRot.Yaw = R.Yaw;
            NewNet_RocketFire(FireMode[Mode]).SavedRot.Pitch = R.Pitch;
            NewNet_RocketFire(FireMode[Mode]).bUseReplicatedInfo=NETClock.IsReasonable(Self, NewNet_RocketFire(FireMode[Mode]).SavedVec);

        }
    }
    else if ( FireMode[Mode].AllowFire() )
    {
        FireMode[Mode].bServerDelayStartFire = true;
	}
	else
		ClientForceAmmoUpdate(Mode, AmmoAmount(Mode));
}


simulated function Weapontick(float deltatime)
{
   lastDT = deltatime;
}
//// client & server ////
simulated function bool StartFire(int Mode)
{
    local int alt;
    local int OtherMode;

	if ( Mode == 0 )
		OtherMode = 1;
	else
		OtherMode = 0;
	if ( FireMode[OtherMode].bIsFiring || (FireMode[OtherMode].NextFireTime > Level.TimeSeconds) )
		return false;

    if (!ReadyToFire(Mode))
        return false;

    if (Mode == 0)
        alt = 1;
    else
        alt = 0;

    FireMode[Mode].bIsFiring = true;

    FireMode[Mode].NextFireTime = Level.TimeSeconds-LastDT*0.5 + FireMode[Mode].PreFireTime;

    if (FireMode[alt].bModeExclusive)
    {
        // prevents rapidly alternating fire modes
        FireMode[Mode].NextFireTime = FMax(FireMode[Mode].NextFireTime, FireMode[alt].NextFireTime);
    }
    if (Instigator.IsLocallyControlled())
    {
        if (FireMode[Mode].PreFireTime > 0.0 || FireMode[Mode].bFireOnRelease)
        {
            FireMode[Mode].PlayPreFire();
        }
        FireMode[Mode].FireCount = 0;
    }
    return true;
}

function Projectile SpawnProjectile(Vector Start, Rotator Dir)
{
    local RocketProj Rocket;
    local SeekingRocketProj SeekingRocket;
	local bot B;
	local actor Other;
	local float f,g;
    local float PingDT;

	local vector HitNormal, End, HitLocation;

	if (Level.NetMode == NM_Client || !IsEnhancedNetcodeEnabled())
	{
	    return super.SpawnProjectile(Start, Dir);
	}
    PingDT = FMin(Client.AveragePing, MAX_PROJECTILE_FUDGE);

    bBreakLock = true;

	// decide if bot should be locked on
	B = Bot(Instigator.Controller);
	if ( (B != None) && (B.Skill > 2 + 5 * FRand()) && (FRand() < 0.6) && (B.Target != None)
		&& (B.Target == B.Enemy) && (VSize(B.Enemy.Location - B.Pawn.Location) > 2000 + 2000 * FRand())
		&& (Level.TimeSeconds - B.LastSeenTime < 0.4) && (Level.TimeSeconds - B.AcquireTime > 1.5) )
	{
		bLockedOn = true;
		SeekTarget = B.Enemy;
	}

    if (bLockedOn && SeekTarget != None)
    {
        if(PingDT > 0.0 && Owner!=None)
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
                Other = HexedNET.TimeTravelTrace(Self, HitLocation, HitNormal, End, Start);
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
               SeekingRocket = Spawn(class'NewNet_SeekingRocketProj',,, End, Dir);
           else
           {
               SeekingRocket = Spawn(class'NewNet_SeekingRocketProj',,, HitLocation - Vector(dir)*20.0, Dir);
           }
        }
        if(SeekingRocket==None)
            SeekingRocket = Spawn(class'NewNet_SeekingRocketProj',,, Start, Dir);

        SeekingRocket.Seeking = SeekTarget;
        if ( B != None )
        {
			//log("LOCKED");
			bLockedOn = false;
			SeekTarget = None;
		}
        return SeekingRocket;
    }
    else
    {
        if(PingDT > 0.0 && Owner!=None)
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
                Other = HexedNET.TimeTravelTrace(Self, HitLocation, HitNormal, End, Start);
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
               Rocket = Spawn(class'NewNet_RocketProj',,, End, Dir);
           else
           {
               Rocket = Spawn(class'NewNet_RocketProj',,, HitLocation - Vector(dir)*20.0, Dir);
           }
        }
        else
            Rocket = Spawn(class'NewNet_RocketProj',,, Start, Dir);
        return Rocket;
    }
}

function vector Extrapolate(out rotator Dir, float dF)
{
    return vector(Dir)*class'NewNet_RocketProj'.default.speed*dF;
}

DefaultProperties
{
    BaseClass=class'RocketLauncher'
    FireModeClass(0)=class'NewNet_RocketFire'
    FireModeClass(1)=class'NewNet_RocketMultiFire'
}
