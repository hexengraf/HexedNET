class HxNet_SniperRifle extends SniperRifle
    DependsOn(HxNTWeapon)
    HideDropDown
    CacheExempt;

var private MutHexedNET HexedNET;
var private HxNTClient Client;
var private float StopFireTime[2];
var private bool bConfigCleared;

replication
{
    reliable if(Role < Role_Authority)
        ServerStartFireBAS;
}

simulated event PreBeginPlay()
{
    Super.PreBeginPlay();
    if (Level.NetMode != NM_DedicatedServer)
    {
        if (!default.bConfigCleared)
        {
            ClearConfig();
            default.bConfigCleared = true;
        }
        class'HxNTWeapon'.static.ForceBaseClassConfig(Self, class'SniperRifle');
    }
}

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    if (Level.NetMode != NM_Client)
    {
        foreach DynamicActors(class'MutHexedNET', HexedNET) break;
    }
    else
    {
        class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client);
    }
}

simulated event WeaponTick(float dt)
{
    Super.WeaponTick(dt);
    class'HxNTWeapon'.static.CheckStopFire(Self, StopFireTime[0], StopFireTime[1]);
}

simulated event ClientStopFire(int Mode)
{
    Super.ClientStopFire(Mode);
    StopFireTime[Mode] = 0;
}

simulated event ClientStartFire(int Mode)
{
    local HxNTWeapon.HxBAS BAS;
    local Actor Injured;

    if (Role == ROLE_Authority || Pawn(Owner).Controller.IsInState('GameEnded')
        || Pawn(Owner).Controller.IsInState('RoundEnded') || SniperFire(FireMode[Mode]) == None
        || !class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        || !Client.IsEnhancedNetcodeEnabled())
    {
        Super.ClientStartFire(Mode);
    }
    else if (StartFire(Mode))
    {
        BAS = GetBAS(Self, Mode, Injured);
        HxNet_SniperFire(FireMode[Mode]).ApplyBAS(BAS);
        ServerStartFireBAS(Mode, BAS, Injured);
        StopFireTime[Mode] = Level.TimeSeconds + (FireMode[Mode].FireRate / 2);
    }
}

function ServerStartFireBAS(byte Mode, HxNTWeapon.HxBAS BAS, Actor Injured)
{
    HxNet_SniperFire(FireMode[Mode]).ApplyBAS(BAS, Injured);
    ServerStartFire(Mode);
}

static final function HxNTWeapon.HxBAS GetBAS(Weapon W, int Mode, out Actor Injured)
{
    local vector HitLocation;
    local vector HitNormal;
    local vector Start;
    local rotator Aim;

    Start = W.Instigator.Location + W.Instigator.EyePosition();
    Aim = W.FireMode[Mode].AdjustAim(Start, W.FireMode[Mode].AimError);
    Aim = rotator(vector(Aim) + VRand() * FRand() * W.FireMode[Mode].Spread);
    Injured = W.Trace(HitLocation, HitNormal, Start + vector(Aim) * 40000.0, Start, true);
    if (Injured != None && !Injured.IsA('xPawn') && !Injured.IsA('Vehicle'))
    {
        Injured = None;
    }
    return class'HxNTWeapon'.static.EncodeBAS(Start, Aim);
}

defaultproperties
{
    FireModeClass(0) = class'HxNet_SniperFire'
}
