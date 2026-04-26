/*
UTComp - UT2004 Mutator
Copyright (C) 2004-2005 Aaron Everitt & Jo�l Moffatt

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/
class HxNTClient extends HxClientReplicationInfo
    config(User);

const PING_WARMUP_COUNT = 10;
const NEW_PING_WEIGHT = 0.33;
const COUNTER_WEIGHT = 0.67;

var config bool bEnhancedNetCode;

var float TimeBetweenPings;
var float PredictedPing;

var private FakeProjectileManager FPM;
var private int PingCount;
var private bool bClientUpdated;

replication
{
    reliable if (Role == ROLE_Authority)
        ClientPing,
        ClientSetAllowMultiHit;

    reliable if (Role < ROLE_Authority)
        ServerPing,
        ServerTurnOffNetcode;
}

simulated function PostNetBeginPlay()
{
    Super.PostNetBeginPlay();
    if (Level.NetMode == NM_Client)
    {
        if (bEnhancedNetCode)
        {
            SetTimer(TimeBetweenPings, true);
        }
    }
}

simulated event Timer()
{
    ServerPing(Level.TimeSeconds);
}

simulated function ServerPing(float Timestamp)
{
    ClientPing(Timestamp);
}

simulated function ClientPing(float Timestamp)
{
    local float NewPing;

    PingCount++;
    NewPing = Level.TimeSeconds - Timestamp;
    if (PingCount < PING_WARMUP_COUNT)
    {
        default.PredictedPing += (NewPing - default.PredictedPing) / PingCount;
    }
    else
    {
        default.PredictedPing = NewPing * NEW_PING_WEIGHT + default.PredictedPing * COUNTER_WEIGHT;
    }
}

simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    if (Level.NetMode == NM_Client)
    {
        if (PlayerController(Owner) != None)
        {
            FixWeaponInstigator(PlayerController(Owner));
        }
    }
    else if (Level.NetMode == NM_DedicatedServer && !bClientUpdated)
    {
        ClientSetAllowMultiHit(class'ZoomSuperShockBeamFire'.default.bAllowMultiHit);
    }
}

function ServerTurnOffNetcode()
{
    local PlayerController PC;
    local inventory Inv;

    PC = PlayerController(Owner);
    if (PC.Pawn != None)
    {
        for (Inv = PC.Pawn.Inventory; Inv != None; Inv = Inv.inventory)
        {
            if (Weapon(Inv) == None)
            {
                continue;
            }
            if (NewNet_AssaultRifle(Inv) != None)
            {
                NewNet_AssaultRifle(Inv).DisableNet();
            }
            else if (NewNet_BioRifle(Inv) != None)
            {
                NewNet_BioRifle(Inv).DisableNet();
            }
            else if (NewNet_ShockRifle(Inv) != None)
            {
                NewNet_ShockRifle(Inv).DisableNet();
            }
            else if (NewNet_SuperShockRifle(Inv) != None)
            {
                NewNet_SuperShockRifle(Inv).DisableNet();
            }
            else if (NewNet_ZoomSuperShockRifle(Inv) != None)
            {
                NewNet_ZoomSuperShockRifle(Inv).DisableNet();
            }
            else if (NewNet_MiniGun(Inv) != None)
            {
                NewNet_MiniGun(Inv).DisableNet();
            }
            else if (NewNet_LinkGun(Inv) != None)
            {
                NewNet_LinkGun(Inv).DisableNet();
            }
            else if (NewNet_RocketLauncher(Inv) != None)
            {
                NewNet_RocketLauncher(Inv).DisableNet();
            }
            else if (NewNet_FlakCannon(Inv) != None)
            {
                NewNet_FlakCannon(Inv).DisableNet();
            }
            else if (NewNet_SniperRifle(Inv) != None)
            {
                NewNet_SniperRifle(Inv).DisableNet();
            }
            else if (NewNet_ClassicSniperRifle(Inv) != None)
            {
                NewNet_ClassicSniperRifle(Inv).DisableNet();
            }
            else if (NewNet_HxSuperShockRifle(Inv) != None)
            {
                NewNet_HxSuperShockRifle(Inv).DisableNet();
            }
            else if (NewNet_HxZoomSuperShockRifle(Inv) != None)
            {
                NewNet_HxZoomSuperShockRifle(Inv).DisableNet();
            }
        }
    }
}

simulated function ServerInfoReady()
{
    FPM = Spawn(Class'FakeProjectileManager', Self);
    SetTimeBetweenPings(GetServerProperty("TimeBetweenPings"));
}

simulated function ServerPropertyChanged(int Index, string OldValue)
{
    SetTimeBetweenPings(GetServerProperty("TimeBetweenPings"));
}

simulated function string GetProperty(int Index)
{
    switch (Index)
    {
        case 0:
            return string(bEnhancedNetCode);
    }
    return "";
}

simulated function SetProperty(int Index, string Value)
{
    if (Index == 0)
    {
        SetEnhancedNetCode(Value);
    }
}

simulated function SetEnhancedNetCode(coerce bool bEnable)
{
    if (!bEnable)
    {
        ServerTurnOffNetcode();
        Disable('Timer');
    }
    else
    {
        Enable('Timer');
        SetTimer(TimeBetweenPings, true);
    }
    bEnhancedNetCode = bEnable;
    default.bEnhancedNetCode = bEnable;
    StaticSaveConfig();
}

simulated function SetTimeBetweenPings(coerce float NewTime)
{
    TimeBetweenPings = NewTime;
    SetTimer(TimeBetweenPings, true);
}

simulated function ClientSetAllowMultiHit(bool bEnable)
{
    class'NewNet_ZoomSuperShockBeamFire'.default.bServerAllowMultiHit = bEnable;
}

// TODO: do we really need this?
static function FixWeaponInstigator(PlayerController PC)
{
    // fix annoying bug where sometimes weapon instigator gets set to none
    // due to race condition in replication
    if (PC.Pawn != None && PC.Pawn.Weapon != None && PC.Pawn.Weapon.Instigator != PC.Pawn)
    {
        PC.Pawn.Weapon.Instigator = PC.Pawn;
    }
}

static function bool IsEnhancedNetcodeEnabled(LevelInfo Level)
{
    return default.bEnhancedNetCode && Level.NetMode == NM_Client;
}

defaultproperties
{
    NetUpdateFrequency=10
    NetPriority=5
    TimeBetweenPings=1
    bEnhancedNetCode=true

    MutatorClass=class'MutHexedNET'
    Properties(0)=(Name="bEnhancedNetCode",Section="Enhanced Netcode",Caption="Enable Enhanced Netcode",Hint="Enable enhanced netcode on weapons.",Type=PIT_Check)
}
