class NewNet_RocketLauncher extends RocketLauncher
    HideDropDown
	CacheExempt;

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
var private bool bConfigCleared;

replication
{
    reliable if(Role < Role_Authority)
        NewNet_ServerStartFire;
}

simulated event PreBeginPlay()
{
    Super.PreBeginPlay();
    if (Level.NetMode != NM_DedicatedServer)
    {
        if (!default.bConfigCleared)
        {
            ClearConfig();
            default.bConfigCleared = true;
        }
        class'HxNTWeapon'.static.ForceBaseClassConfig(Self, class'RocketLauncher');
    }
}

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    if (Level.NetMode != NM_Client)
    {
        foreach DynamicActors(class'MutHexedNET', HexedNET) break;
    }
    class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client);
}

simulated function bool IsEnhancedNetcodeEnabled()
{
    return class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        && Client.IsEnhancedNetcodeEnabled();
}

simulated event ClientStartFire(int Mode)
{
    local NewNet_RocketFire RocketFire;
    local ReplicatedRotator R;
    local ReplicatedVector V;
    local vector Start;
	local int OtherMode;

    if (Level.NetMode != NM_Client
        || !IsEnhancedNetcodeEnabled()
        || Pawn(Owner).Controller.IsInState('GameEnded')
        || Pawn(Owner).Controller.IsInState('RoundEnded'))
    {
        Super.ClientStartFire(Mode);
    }
    else
    {
        if (RocketMultiFire(FireMode[Mode]) != None)
        {
            SetTightSpread(false);
        }
        else
        {
            if (Mode == 0)
            {
                OtherMode = 1;
            }
            else
            {
                OtherMode = 0;
            }
            if (FireMode[OtherMode].bIsFiring || (FireMode[OtherMode].NextFireTime > Level.TimeSeconds))
            {
                if (FireMode[OtherMode].Load > 0)
                {
                    SetTightSpread(true);
                }
                if (bDebugging)
                {
                    log("No RL reg fire because other firing "$FireMode[OtherMode].bIsFiring
                        $" next fire "$(FireMode[OtherMode].NextFireTime - Level.TimeSeconds));
                }
                return;
            }
        }
        if (Role < ROLE_Authority)
        {
            if (StartFire(Mode))
            {
                R.Pitch = Pawn(Owner).Controller.Rotation.Pitch;
                R.Yaw = Pawn(Owner).Controller.Rotation.Yaw;
                Start = Pawn(Owner).Location + Pawn(Owner).EyePosition();
                V.X = Start.X;
                V.Y = Start.Y;
                V.Z = Start.Z;
                RocketFire = NewNet_RocketFire(FireMode[Mode]);
                if (RocketFire != None)
                {
                    RocketFire.SavedVec.X = V.X;
                    RocketFire.SavedVec.Y = V.Y;
                    RocketFire.SavedVec.Z = V.Z;
                    RocketFire.SavedRot.Yaw = R.Yaw;
                    RocketFire.SavedRot.Pitch = R.Pitch;
                    RocketFire.EnqueueStopFire();
                }
                NewNet_ServerStartFire(mode, R, V);
            }
        }
        else
        {
            StartFire(Mode);
        }
    }
}

function NewNet_ServerStartFire(byte Mode, ReplicatedRotator R, ReplicatedVector V)
{
    local NewNet_RocketFire RocketFire;

    if (Instigator != None && Instigator.Weapon != Self)
    {
        if (Instigator.Weapon == None)
        {
            Instigator.ServerChangedWeapon(None, Self);
        }
        else
        {
            Instigator.Weapon.SynchronizeWeapon(Self);
        }
        return;
    }
    RocketFire = NewNet_RocketFire(FireMode[Mode]);
    if (RocketFire != None)
    {
        RocketFire.SavedVec.X = V.X;
        RocketFire.SavedVec.Y = V.Y;
        RocketFire.SavedVec.Z = V.Z;
        RocketFire.SavedRot.Yaw = R.Yaw;
        RocketFire.SavedRot.Pitch = R.Pitch;
        RocketFire.bUseReplicatedInfo = HexedNET.IsReasonable(Self, RocketFire.SavedVec);
    }
    if (FireMode[Mode].NextFireTime <= Level.TimeSeconds + FireMode[Mode].PreFireTime
        && StartFire(Mode))
    {
        FireMode[Mode].ServerStartFireTime = Level.TimeSeconds;
        FireMode[Mode].bServerDelayStartFire = false;
    }
    else if (FireMode[Mode].AllowFire())
    {
        FireMode[Mode].bServerDelayStartFire = true;
    }
    else
    {
        ClientForceAmmoUpdate(Mode, AmmoAmount(Mode));
    }
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
    PingDT = Client.GetProjectilePing();

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
    FireModeClass(0)=class'NewNet_RocketFire'
    FireModeClass(1)=class'NewNet_RocketMultiFire'
}
