
class NewNet_ClassicSniperRifle extends ClassicSniperRifle
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
    NewNet_ClassicSniperFire(FireMode[0]).bUseEnhancedNetCode = false;
    NewNet_ClassicSniperFire(FireMode[0]).PingDT = 0.00;
}

simulated function ClientStartFire(int mode)
{
    if (mode == 1)
    {
        FireMode[mode].bIsFiring = true;
        if( Instigator.Controller.IsA( 'PlayerController' ) )
            PlayerController(Instigator.Controller).ToggleZoom();
    }
    else
    {
        SuperClientStartFire(mode);
    }
}

simulated event SuperClientStartFire(int Mode)
{
    if(Level.NetMode!=NM_Client || !class'HxNTClient'.static.IsEnhancedNetcodeEnabled())
        super(Weapon).ClientStartFire(mode);
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
    if(NewNet_ClassicSniperFire(FireMode[Mode])!=None)
    {
        NewNet_ClassicSniperFire(FireMode[Mode]).PingDT = NETClock.GetPingDT(ClientCounter, DT);
        NewNet_ClassicSniperFire(FireMode[Mode]).bUseEnhancedNetCode = true;
    }

    ServerStartFire(Mode);
}

DefaultProperties
{
    FireModeClass(0)=class'NewNet_ClassicSniperFire'
}
