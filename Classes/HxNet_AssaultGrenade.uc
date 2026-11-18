class HxNet_AssaultGrenade extends AssaultGrenade
    DependsOn(HxNTWeapon);

var private float DelayedHoldTime;
#include Classes\Include\HxNTBaseProjectileFire.uci

function SaveDelayedState()
{
    DelayedHoldTime = HoldTime;
}

function DoFireEffect()
{
    local Vector Start;
    local Rotator Dir;
    local Vector HitLocation;
    local Vector HitNormal;
    local Vector X;
    local Vector Y;
    local Vector Z;

    if (WantsLagCompensation())
    {
        Instigator.MakeNoise(1.0);
        if (bUseBAS)
        {
            bUseBAS = false;
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
        SpawnHexedProjectile(Start, Dir);
    }
    else
    {
        Super.DoFireEffect();
    }
}

function Projectile SpawnHexedProjectile(Vector Start, Rotator Dir)
{
    local Grenade P;

    if (Level.NetMode == NM_Client)
    {
        P = Weapon.Spawn(class'HxNet_GrenadePredicted', instigator,, Start, Dir);
        if (P != None)
        {
            HxNet_GrenadePredicted(P).WeaponInfo = WeaponInfo;
            HxNet_GrenadePredicted(P).SpawnRandomGenerator(WeaponInfo.Generator);
            UpdateSpeedAndDamage(P, Dir);
        }
        return WeaponInfo.AddPredictedProjectile(P);
    }
    P = Weapon.Spawn(class'HxNet_Grenade', instigator,, Start, Dir);
    WeaponInfo.AssignUniqueID(P);
    if (P != None)
    {
        HxNet_Grenade(P).Client = Client;
        HxNet_Grenade(P).SpawnRandomGenerator(WeaponInfo.Generator);
        UpdateSpeedAndDamage(P, Dir);
        HexedNET.ForwardBouncingProjectile(Weapon, P, GetCompensationTime());
        if (P != None && P.bTimerSet && P.TimerRate > 0)
        {
            P.ExplodeTimer = P.TimerRate;
        }
    }
    return P;
}

function UpdateSpeedAndDamage(Grenade G, Rotator Dir)
{
    local Vector X;
    local Vector Y;
    local Vector Z;

    GetAxes(Dir, X, Y, Z);
    if (bIsDelayed)
    {
        G.Speed = mHoldSpeedMin + DelayedHoldTime * mHoldSpeedGainPerSec;
    }
    else
    {
        G.Speed = mHoldSpeedMin + HoldTime * mHoldSpeedGainPerSec;
    }
    G.Speed = FClamp(G.Speed, mHoldSpeedMin, mHoldSpeedMax);
    G.Speed = (X dot Instigator.Velocity) + G.Speed;
    G.Velocity = G.Speed * Vector(Dir);
    G.Damage *= DamageAtten;
}

defaultproperties
{
    WeaponClass=class'AssaultRifle'
}
