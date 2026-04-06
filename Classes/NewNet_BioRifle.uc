//-----------------------------------------------------------
class NewNet_BioRifle extends BioRifle
	HideDropDown
	CacheExempt;

const MAX_PROJECTILE_FUDGE = 0.075;

var HxNTClock C;
var MutHexedNET M;

var int CurIndex;
var int ClientCurIndex;

replication
{
    reliable if( Role<ROLE_Authority )
        NewNet_ServerStartFire;
    unreliable if(Role == Role_Authority && bNetOwner)
        CurIndex;
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
            if(C==None)
                foreach DynamicActors(class'HxNTClock', C)
                     break;

            NewNet_ServerStartFire(mode, C.ClientCounter, C.Dt);
        }
    }
    else
    {
        StartFire(Mode);
    }
}

function NewNet_ServerStartFire(byte Mode, byte ClientCounter, float DT)
{
    if(M==None)
        foreach DynamicActors(class'MutHexedNET', M)
	        break;

    if(NewNet_BioFire(FireMode[Mode])!=None)
    {
        NewNet_BioFire(FireMode[Mode]).PingDT = FMin(M.ClientTimeStamp - M.GetTimestamp(ClientCounter)-DT + 0.5*M.AverDT, MAX_PROJECTILE_FUDGE);
        NewNet_BioFire(FireMode[Mode]).bUseEnhancedNetCode = true;
    }
    else if(NewNet_BioChargedFire(FireMode[Mode])!=None)
    {
        NewNet_BioChargedFire(FireMode[Mode]).PingDT = FMin(M.ClientTimeStamp - M.GetTimestamp(ClientCounter)-DT + 0.5*M.AverDT, MAX_PROJECTILE_FUDGE);
        NewNet_BioChargedFire(FireMode[Mode]).bUseEnhancedNetCode = true;
    }

    ServerStartFire(Mode);
}

DefaultProperties
{
    FireModeClass(0)=class'NewNet_BioFire'
    FireModeClass(1)=class'NewNet_BioChargedFire'
}
