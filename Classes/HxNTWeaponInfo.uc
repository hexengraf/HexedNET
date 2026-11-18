class HxNTWeaponInfo extends Object;

var class<Weapon> WeaponClass;
var HxRandomGeneratorAlt Generator;
var private array<Projectile> PredProjectiles;
var private array<Projectile> AuthProjectiles;
var private array<int> PredUIDs;
var private array<int> AuthUIDs;
var private int UIDSeed;

function AllocateRandomGenerator(LevelInfo Level)
{
    if (Generator == None)
    {
        Generator = HxRandomGeneratorAlt(
            Level.ObjectPool.AllocateObject(class'HxRandomGeneratorAlt'));
    }
}

function DeallocateRandomGenerator(LevelInfo Level)
{
    if (Generator != None)
    {
        Level.ObjectPool.FreeObject(Generator);
        Generator = None;
    }
}

function Synchronize(int BaseSeed, float Timestamp)
{
    UIDSeed = BaseSeed ^ class'HxRandomGeneratorAlt'.static.Mix(int(Timestamp * 1000));
    Generator.SetSeed(UIDSeed);
}

function Projectile AssignUniqueID(Projectile P)
{
    local int UID;

    UID = class'HxRandomGeneratorAlt'.static.Next(UIDSeed);
    if (P != None)
    {
        P.SetPropertyText("UID", string(UID));
    }
    return P;
}

function Projectile MatchPrediction(Projectile AuthProjectile, int UID)
{
    local Projectile P;
    local int i;

    for (i = PredProjectiles.Length - 1; i >= 0; --i)
    {
        if (PredProjectiles[i] == None)
        {
            PredProjectiles.Remove(i, 1);
        }
        else if (PredUIDs[i] == UID)
        {
            P = PredProjectiles[i];
            P.bNoFX = true;
            InternalRemovePredictedProjectile(i);
            return P;
        }
    }
    AuthProjectile.SetPropertyText("bShouldRemove", "true");
    AuthProjectiles[AuthProjectiles.Length] = AuthProjectile;
    AuthUIDs[AuthUIDs.Length] = UID;
    return None;
}

function bool RemoveAuthoritativeProjectile(Projectile P)
{
    local int i;

    for (i = 0; i < AuthProjectiles.Length; ++i)
    {
        if (AuthProjectiles[i] == P)
        {
            InternalRemoveAuthoritativeProjectile(i);
            return true;
        }
    }
    return false;
}

function Projectile AddPredictedProjectile(Projectile P)
{
    local int UID;
    local int i;

    UID = class'HxRandomGeneratorAlt'.static.Next(UIDSeed);
    if (P != None)
    {
        for (i = AuthProjectiles.Length - 1; i >= 0; --i)
        {
            if (AuthProjectiles[i] == None)
            {
                AuthProjectiles.Remove(i, 1);
                AuthUIDs.Remove(i, 1);
            }
            else if (AuthUIDs[i] == UID)
            {
                InternalRemoveAuthoritativeProjectile(i);
                P.SetPropertyText("bRemoved", "true");
                P.bNoFX = true;
                P.Destroy();
                return P;
            }
        }
        PredProjectiles[PredProjectiles.Length] = P;
        PredUIDs[PredUIDs.Length] = UID;
    }
    return P;
}

function bool RemovePredictedProjectile(Projectile P)
{
    local int i;

    for (i = 0; i < PredProjectiles.Length; ++i)
    {
        if (PredProjectiles[i] == P)
        {
            InternalRemovePredictedProjectile(i);
            return true;
        }
    }
    return false;
}

private function InternalRemoveAuthoritativeProjectile(int Index)
{
    AuthProjectiles[Index].SetPropertyText("bShouldRemove", "false");
    AuthProjectiles.Remove(Index, 1);
    AuthUIDs.Remove(Index, 1);
}

private function InternalRemovePredictedProjectile(int Index)
{
    PredProjectiles[Index].SetPropertyText("bRemoved", "true");
    PredProjectiles.Remove(Index, 1);
    PredUIDs.Remove(Index, 1);
}

defaultproperties
{
}
