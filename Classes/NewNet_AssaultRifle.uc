class NewNet_AssaultRifle extends AssaultRifle
    HideDropDown
    CacheExempt;

const MAX_PROJECTILE_FUDGE = 0.075;

var private HxNTClock NETClock;

replication
{
    reliable if (Role < ROLE_Authority)
        NewNet_ServerStartFire;

    unreliable if (Role == Role_Authority)
        DispatchClientEffect;
}

#include Classes\Include\WeaponBaseFunctions.uci
#include Classes\Include\WeaponStartFireStandard.uci

function NewNet_ServerStartFire(byte Mode, byte ClientCounter, float DT)
{
    ValidateNETClockPointer();
    if (NewNet_AssaultFire(FireMode[Mode]) != None)
    {
        NewNet_AssaultFire(FireMode[Mode]).PingDT = NETClock.GetPingDT(ClientCounter, DT);
        NewNet_AssaultFire(FireMode[Mode]).bUseEnhancedNetCode = true;
    }
    else if (NewNet_AssaultGrenade(FireMode[Mode]) != None)
    {
        NewNet_AssaultGrenade(FireMode[Mode]).PingDT =
            FMin(NETClock.GetPingDT(ClientCounter, DT), MAX_PROJECTILE_FUDGE);
        NewNet_AssaultGrenade(FireMode[Mode]).bUseEnhancedNetCode = true;
    }
    ServerStartFire(Mode);
}

simulated function DispatchClientEffect(Vector V, rotator R)
{
    if(Level.NetMode == NM_Client)
    {
        Spawn(class'LinkProjectile',,, V, R);
    }
}

DefaultProperties
{
    FireModeClass(0)=class'NewNet_AssaultFire'
    FireModeClass(1)=class'NewNet_AssaultGrenade'
}
