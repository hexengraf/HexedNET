class HxNTGameRules extends GameRules;

var MutHexedNET HexedNET;
var float OvertimeEndTime;
var bool bFirstRun;
var bool bFirstEndOvertime;

function bool CheckEndGame(PlayerReplicationInfo Winner, string Reason)
{
    if(HexedNET.TimedOvertime > 0 && Level.Game.bOverTime)
    {
        if(!OvertimeOver())
        {
            return False;
        }
    }
    if (NextGameRules != None)
    {
		return NextGameRules.CheckEndGame(Winner, Reason);
    }
	return True;
}

function bool OvertimeOver()
{
    if (bFirstRun)
    {
        OvertimeEndTime = Level.TimeSeconds + HexedNET.TimedOvertime * Level.TimeDilation;
        UpdateClock((OvertimeEndTime - Level.TimeSeconds) / Level.TimeDilation);
        bFirstRun = False;
        return False;
    }
    UpdateClock((OvertimeEndTime - Level.TimeSeconds) / Level.TimeDilation);
    return Level.TimeSeconds >= OvertimeEndTime;
}

function UpdateClock(float F)
{
    if (bFirstEndOvertime && F <= 0.0)
    {
        bFirstEndOvertime = False;
    }
}

function Reset()
{
    Super.Reset();
    bFirstRun = True;
    bFirstEndOvertime = True;
    OvertimeEndTime = 0.0;
}

defaultproperties
{
    bFirstRun=True
    bFirstEndOvertime=True
}
