class NewNet_LinkGun extends LinkGun
    HideDropDown
    CacheExempt;

const MAX_PROJECTILE_FUDGE = 0.075;

var int CurIndex;

var private HxNTClock NETClock;

replication
{
    reliable if (Role<ROLE_Authority)
        NewNet_ServerStartFire;

    // unreliable if (Role == Role_Authority)
    //     DispatchClientEffect;

    unreliable if (Role == Role_Authority && bNetOwner)
        CurIndex;
}

#include Classes\Include\WeaponBaseFunctions.uci
#include Classes\Include\WeaponStartFireStandard.uci

function NewNet_ServerStartFire(byte Mode, byte ClientCounter, float DT)
{
    ValidateNETClockPointer();
    if (NewNet_LinkAltFire(FireMode[Mode]) != None)
    {
        NewNet_LinkAltFire(FireMode[Mode]).PingDT =
            FMin(NETClock.GetPingDT(ClientCounter, DT), MAX_PROJECTILE_FUDGE);
        NewNet_LinkAltFire(FireMode[Mode]).bUseEnhancedNetCode = true;
    }
    else if (NewNet_LinkFire(FireMode[Mode]) != None)
    {
        NewNet_LinkFire(FireMode[Mode]).PingDT = NETClock.GetPingDT(ClientCounter, DT);
        NewNet_LinkFire(FireMode[Mode]).bUseEnhancedNetCode = true;
    }
    ServerStartFire(Mode);
}

simulated function DispatchClientEffect(Vector V, rotator R)
{
    if (Level.NetMode == NM_Client)
    {
        Spawn(class'LinkProjectile',,, V, R);
    }
}

DefaultProperties
{
    FireModeClass(0)=class'NewNet_LinkAltFire'
    FireModeClass(1)=class'NewNet_LinkFire'
}
