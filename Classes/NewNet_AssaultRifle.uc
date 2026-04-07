class NewNet_AssaultRifle extends AssaultRifle
	HideDropDown
	CacheExempt;

var private HxNTClock NETClock;

const MAX_PROJECTILE_FUDGE = 0.075;

replication
{
    reliable if (Role < ROLE_Authority)
        NewNet_ServerStartFire;

    unreliable if (Role == Role_Authority)
        DispatchClientEffect;
}

#include Classes\Include\WeaponBaseFunctions.uci

//// client only ////
simulated event ClientStartFire(int Mode)
{
    if (class'HxNTClient'.static.IsEnhancedNetcodeEnabled(Level))
    {
        NewNet_ClientStartFire(mode);
    }
    else
    {
        Super.ClientStartFire(mode);
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
    if(NewNet_AssaultFire(FireMode[Mode])!=None)
    {
        NewNet_AssaultFire(FireMode[Mode]).PingDT = NETClock.GetPingDT(ClientCounter, DT);
        NewNet_AssaultFire(FireMode[Mode]).bUseEnhancedNetCode = true;
    }
    else if(NewNet_AssaultGrenade(FireMode[Mode])!=None)
    {
        NewNet_AssaultGrenade(FireMode[Mode]).PingDT = FMin(NETClock.GetPingDT(ClientCounter, DT), MAX_PROJECTILE_FUDGE);
        NewNet_AssaultGrenade(FireMode[Mode]).bUseEnhancedNetCode = true;
    }

    ServerStartFire(Mode);
}

simulated function DispatchClientEffect(Vector V, rotator R)
{
    if(Level.NetMode != NM_Client)
        return;
    Spawn(class'LinkProjectile',,,V,R);
}

DefaultProperties
{
    FireModeClass(0)=class'NewNet_AssaultFire'
    FireModeClass(1)=class'NewNet_AssaultGrenade'
}
