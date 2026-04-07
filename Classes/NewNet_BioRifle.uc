class NewNet_BioRifle extends BioRifle
	HideDropDown
	CacheExempt;

const MAX_PROJECTILE_FUDGE = 0.075;

var private HxNTClock NETClock;

var int CurIndex;
var int ClientCurIndex;

replication
{
    reliable if( Role<ROLE_Authority )
        NewNet_ServerStartFire;
    unreliable if(Role == Role_Authority && bNetOwner)
        CurIndex;
}

simulated event PreBeginPlay()
{
    Super.PreBeginPlay();
    ForEach DynamicActors(class'HxNTClock', NETClock) break;
}

simulated function ValidateNETClockPointer()
{
    if (NETClock == None)
    {
        ForEach DynamicActors(class'HxNTClock', NETClock) break;
    }
}

function DisableNet()
{
    NewNet_BioFire(FireMode[0]).bUseEnhancedNetCode = false;
    NewNet_BioFire(FireMode[0]).PingDT = 0.00;
    NewNet_BioChargedFire(FireMode[1]).bUseEnhancedNetCode = false;
    NewNet_BioChargedFire(FireMode[1]).PingDT = 0.00;
}

//// client only ////
simulated event ClientStartFire(int Mode)
{
    if(Level.NetMode!=NM_Client || !class'HxNTClient'.static.IsEnhancedNetcodeEnabled())
        super.ClientStartFire(mode);
    else
        NewNet_ClientStartFire(mode);
}

simulated event NewNet_ClientStartFire(int Mode)
{
    if ( Pawn(Owner).Controller.IsInState('GameEnded') || Pawn(Owner).Controller.IsInState('RoundEnded') )
        return;
    if (Role < ROLE_Authority)
    {
        if (StartFire(Mode))
        {
            ValidateNETClockPointer();
            NewNet_ServerStartFire(mode, NETClock.ClientCounter, NETClock.DT);
        }
    }
    else
    {
        StartFire(Mode);
    }
}

function NewNet_ServerStartFire(byte Mode, byte ClientCounter, float DT)
{
    ValidateNETClockPointer();
    if(NewNet_BioFire(FireMode[Mode])!=None)
    {
        NewNet_BioFire(FireMode[Mode]).PingDT = FMin(NETClock.GetPingDT(ClientCounter, DT), MAX_PROJECTILE_FUDGE);
        NewNet_BioFire(FireMode[Mode]).bUseEnhancedNetCode = true;
    }
    else if(NewNet_BioChargedFire(FireMode[Mode])!=None)
    {
        NewNet_BioChargedFire(FireMode[Mode]).PingDT = FMin(NETClock.GetPingDT(ClientCounter, DT), MAX_PROJECTILE_FUDGE);
        NewNet_BioChargedFire(FireMode[Mode]).bUseEnhancedNetCode = true;
    }

    ServerStartFire(Mode);
}

DefaultProperties
{
    FireModeClass(0)=class'NewNet_BioFire'
    FireModeClass(1)=class'NewNet_BioChargedFire'
}
