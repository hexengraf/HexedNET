
class NewNet_ClassicSniperRifle extends ClassicSniperRifle
    HideDropDown
	CacheExempt;

var HxNTClock C;
var MutHexedNET M;

replication
{
    reliable if( Role<ROLE_Authority )
        NewNet_ServerStartFire;
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
            if(C==None)
                foreach DynamicActors(class'HxNTClock', C)
                     break;

            NewNet_ServerStartFire(mode, C.ClientCounter, C.dt);
        }
    }
    else
    {
        StartFire(Mode);
    }
}

function NewNet_ServerStartFire(byte Mode, byte ClientCounter, float dt)
{
    if(M==None)
        foreach DynamicActors(class'MutHexedNET', M)
	        break;

    if(NewNet_ClassicSniperFire(FireMode[Mode])!=None)
    {
        NewNet_ClassicSniperFire(FireMode[Mode]).PingDT = M.ClientTimeStamp - M.GetTimestamp(ClientCounter)-DT + 0.5*M.AverDT;
        NewNet_ClassicSniperFire(FireMode[Mode]).bUseEnhancedNetCode = true;
    }

    ServerStartFire(Mode);
}

DefaultProperties
{
    FireModeClass(0)=class'NewNet_ClassicSniperFire'
}
