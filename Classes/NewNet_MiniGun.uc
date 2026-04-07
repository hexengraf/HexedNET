class NewNet_MiniGun extends MiniGun
	HideDropDown
	CacheExempt;

var MutHexedNET M;
var private HxNTClock NETClock;

replication
{
    reliable if( Role<ROLE_Authority )
        NewNet_ServerStartFire;
}

simulated event PreBeginPlay()
{
    Super.PreBeginPlay();
    ForEach DynamicActors(class'MutHexedNET', M) break;
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
    NewNet_MiniGunFire(FireMode[0]).bUseEnhancedNetCode = false;
    NewNet_MiniGunFire(FireMode[0]).PingDT = 0.00;
    NewNet_MiniGunAltFire(FireMode[1]).bUseEnhancedNetCode = false;
    NewNet_MiniGunAltFire(FireMode[1]).PingDT = 0.00;
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

function NewNet_ServerStartFire(byte Mode, byte ClientCounter, float dt)
{
    ValidateNETClockPointer();
    if(NewNet_MiniGunFire(FireMode[Mode])!=None)
    {
        NewNet_MiniGunFire(FireMode[Mode]).PingDT = NETClock.GetPingDT(ClientCounter, DT);
        NewNet_MiniGunFire(FireMode[Mode]).bUseEnhancedNetCode = true;
    }
    else if(NewNet_MiniGunAltFire(FireMode[Mode])!=None)
    {
        NewNet_MiniGunAltFire(FireMode[Mode]).PingDT = NETClock.GetPingDT(ClientCounter, DT);
        NewNet_MiniGunAltFire(FireMode[Mode]).bUseEnhancedNetCode = true;
    }

    ServerStartFire(Mode);
}

DefaultProperties
{
    FireModeClass(0)=class'NewNet_MiniGunFire'
    FireModeClass(1)=class'NewNet_MiniGunAltFire'
}
