class NewNet_LinkGun extends LinkGun
	HideDropDown
	CacheExempt;

var private HxNTClock NETClock;

const MAX_PROJECTILE_FUDGE = 0.075;

var int CurIndex;

replication
{
    reliable if( Role<ROLE_Authority )
        NewNet_ServerStartFire;
 /*   unreliable if(Role == Role_Authority)
        DispatchClientEffect;   */
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
    NewNet_LinkAltFire(FireMode[0]).bUseEnhancedNetCode = false;
    NewNet_LinkAltFire(FireMode[0]).PingDT = 0.00;
    NewNet_LinkFire(FireMode[1]).bUseEnhancedNetCode = false;
    NewNet_LinkFire(FireMode[1]).PingDT = 0.00;
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
    if(NewNet_LinkAltFire(FireMode[Mode])!=None)
    {
        NewNet_LinkAltFire(FireMode[Mode]).PingDT = FMin(NETClock.GetPingDT(ClientCounter, DT), MAX_PROJECTILE_FUDGE);
        NewNet_LinkAltFire(FireMode[Mode]).bUseEnhancedNetCode = true;
    }
    else if(NewNet_LinkFire(FireMode[Mode])!=None)
    {
        NewNet_LinkFire(FireMode[Mode]).PingDT = NETClock.GetPingDT(ClientCounter, DT);
        NewNet_LinkFire(FireMode[Mode]).bUseEnhancedNetCode = true;
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
    FireModeClass(0)=class'NewNet_LinkAltFire'
    FireModeClass(1)=class'NewNet_LinkFire'
}
