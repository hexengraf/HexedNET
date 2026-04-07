class NewNet_ClassicSniperRifle extends ClassicSniperRifle
    HideDropDown
	CacheExempt;

var private HxNTClock NETClock;

replication
{
    reliable if( Role<ROLE_Authority )
        NewNet_ServerStartFire;
}

#include Classes\Include\WeaponBaseFunctions.uci

simulated function ClientStartFire(int Mode)
{
    if (Mode == 0 && class'HxNTClient'.static.IsEnhancedNetcodeEnabled(Level))
    {
        NewNet_ClientStartFire(Mode);
    }
    else
    {
        Super.ClientStartFire(Mode);
    }
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
            NewNet_ServerStartFire(Mode, NETClock.ClientCounter, NETClock.DT);
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
