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
const PING_SMOOTHING = 0.3;

var config bool bEnhancedNetcode;

var float AveragePing;

var private HxNTUserConfig Config;
var private FakeProjectileManager FPM;
var private int PingCount;
var private bool bClientEnhancedNetcode;
var private bool bClientUpdated;

replication
{
    reliable if (Role == ROLE_Authority)
        ClientRequestPing,
        ClientUpdatePing,
        ClientSetAllowMultiHit;

    reliable if (Role < ROLE_Authority)
        ServerPing,
        ServerSetEnhancedNetcode;
}

simulated event PreBeginPlay()
{
    Super.PreBeginPlay();
    if (Level.NetMode != NM_DedicatedServer)
    {
        Config = HxNTUserConfig(class'HxNTUserConfig'.static.Load());
    }
}

simulated event PostNetBeginPlay()
{
    Super.PostNetBeginPlay();
    if (Level.NetMode == NM_Client)
    {
        ServerSetEnhancedNetcode(Config.bEnhancedNetcode);
    }
}

simulated function ClientRequestPing(float Timestamp)
{
    ServerPing(Timestamp);
}

simulated function ClientUpdatePing(float Ping)
{
    AveragePing = Ping;
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

event Timer()
{
    ClientRequestPing(Level.TimeSeconds);
}

function ServerPing(float Timestamp)
{
    local float NewPing;

    PingCount++;
    NewPing = Level.TimeSeconds - Timestamp;
    if (PingCount < PING_WARMUP_COUNT)
    {
        AveragePing += (NewPing - AveragePing) / PingCount;
    }
    else
    {
        AveragePing += (NewPing - AveragePing) * PING_SMOOTHING;
    }
    ClientUpdatePing(AveragePing);
}

function ServerSetEnhancedNetcode(bool bEnable)
{
    bClientEnhancedNetcode = bEnable;
    if (!bEnable)
    {
        Disable('Timer');
    }
    else
    {
        Enable('Timer');
        SetTimer(1.0 / float(GetServerProperty("PingFrequency")), true);
    }
}

function SetServerProperty(int Index, string Value)
{
    Super.SetServerProperty(Index, Value);
    if (bClientEnhancedNetcode)
    {
        SetTimer(1.0 / float(GetServerProperty("PingFrequency")), true);
    }
}

simulated function ServerInfoReady()
{
    FPM = Spawn(Class'FakeProjectileManager', Self);
}

simulated function string GetProperty(int Index)
{
    switch (Index)
    {
        case 0:
            return string(Config.bEnhancedNetcode);
    }
    return "";
}

simulated function SetProperty(int Index, string Value)
{
    if (Index == 0)
    {
        Config.bEnhancedNetcode = bool(Value);
        ServerSetEnhancedNetcode(Config.bEnhancedNetcode);
    }
    Config.SaveConfig();
}

simulated function ClientSetAllowMultiHit(bool bEnable)
{
    class'NewNet_ZoomSuperShockBeamFire'.default.bServerAllowMultiHit = bEnable;
}

simulated function bool IsEnhancedNetcodeEnabled()
{
    return (Level.NetMode == NM_Client && Config.bEnhancedNetcode) || bClientEnhancedNetcode;
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

defaultproperties
{
    NetUpdateFrequency=10
    NetPriority=3

    MutatorClass=class'MutHexedNET'
    Properties(0)=(Name="bEnhancedNetcode",Section="Enhanced Netcode",Caption="Enable Enhanced Netcode",Hint="Enable enhanced netcode on weapons.",Type=PIT_Check)
}
