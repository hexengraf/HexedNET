class HxNet_AssaultGrenade extends AssaultGrenade
    DependsOn(HxNTWeapon);

#include Classes\Include\HxNTBaseProjectileFire.uci

function DoFireEffect()
{
    local Vector Start;
    local Rotator Dir;
    local Vector HitLocation;
    local Vector HitNormal;
    local Vector X;
    local Vector Y;
    local Vector Z;

    if (WantsPingCompensation())
    {
        Instigator.MakeNoise(1.0);
        if (bBoostedAimSynchronization)
        {
            bBoostedAimSynchronization = false;
            Dir = BASAim;
        }
        else
        {
            BASStart = Instigator.Location + Instigator.EyePosition();
            if (Instigator.Controller != None)
            {
                BASAim = Instigator.Controller.Rotation;
            }
            else
            {
                BASAim = Instigator.Rotation;
            }
            Dir = AdjustAim(Start, AimError);
        }
        GetAxes(BASAim, X, Y, Z);
        Start = BASStart + X * ProjSpawnOffset.X;
        if (AssaultRifle(Weapon).bDualMode)
        {
            AssaultRifle(Weapon).bFireLeft = !AssaultRifle(Weapon).bFireLeft;
            if (AssaultRifle(Weapon).bFireLeft)
            {
                Y *= -1;
            }
        }
        if (!Weapon.WeaponCentered())
        {
            Start = Start + Weapon.Hand * Y * ProjSpawnOffset.Y + Z * ProjSpawnOffset.Z;
        }
        if (Weapon.Trace(HitLocation, HitNormal, Start, BASStart, false) != None)
        {
            Start = HitLocation;
        }
        SpawnHexedProjectile(Client.GetWeaponInfo(WeaponClass), Start, Dir);
    }
    else
    {
        Super.DoFireEffect();
    }
}

function Projectile SpawnHexedProjectile(HxNTWeaponInfo WeaponInfo,
                                         Vector Start,
                                         Rotator Dir,
                                         optional int Index)
{
    local Grenade G;

    if (Level.NetMode == NM_Client)
    {
        G = Weapon.Spawn(class'HxNet_GrenadePredicted', instigator,, Start, Dir);
        if (G != None)
        {
            HxNet_GrenadePredicted(G).WeaponInfo = WeaponInfo;
            HxNet_GrenadePredicted(G).SpawnRandomGenerator(WeaponInfo.Generator.RandInt());
            WeaponInfo.TrackProjectile(G);
            UpdateSpeedAndDamage(G, Dir);
        }
    }
    else
    {
        G = Weapon.Spawn(class'HxNet_Grenade', instigator,, Start, Dir);
        if (G != None)
        {
            HxNet_Grenade(G).Client = Client;
            HxNet_Grenade(G).SpawnRandomGenerator(WeaponInfo.Generator.RandInt());
            UpdateSpeedAndDamage(G, Dir);
            HexedNET.ForwardBouncingProjectile(Weapon, G, Client.GetProjectileCompensationTime() + ServerDelay);
            if (G != None && G.bTimerSet && G.TimerRate > 0)
            {
                G.ExplodeTimer = G.TimerRate;
            }
        }
    }
    return G;
}

function UpdateSpeedAndDamage(Grenade G, Rotator Dir)
{
    local Vector X;
    local Vector Y;
    local Vector Z;

    GetAxes(Dir, X, Y, Z);
    G.Speed = mHoldSpeedMin + HoldTime * mHoldSpeedGainPerSec;
    G.Speed = FClamp(G.Speed, mHoldSpeedMin, mHoldSpeedMax);
    G.Speed = (X dot Instigator.Velocity) + G.Speed;
    G.Velocity = G.Speed * Vector(Dir);
    G.Damage *= DamageAtten;
}

defaultproperties
{
    WeaponClass=class'AssaultRifle'
}
