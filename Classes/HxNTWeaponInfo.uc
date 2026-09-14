class HxNTWeaponInfo extends Object;

struct HxPredictedProjectile
{
    var Projectile Predicted;
    var int Index;
};

var class<Weapon> WeaponClass;
var HxRandomGenerator Generator;
var private array<Projectile> Projectiles;
var private array<int> Indices;

simulated function RefreshSeed(HxRandomGeneratorAlt Seeder)
{
    Generator.SetSeed(Seeder.RandInt(), Seeder.RandInt(), Seeder.RandInt(), Seeder.RandInt());
}

simulated function Projectile MatchProjectileFull(Vector SearchLocation,
                                                  class<Projectile> ProjectileClass,
                                                  int Index)
{
    local Projectile P;
    local float MinDistance;
    local float Distance;
    local int MatchedIndex;
    local int i;

    if (Projectiles.Length > 0)
    {
        MatchedIndex = -1;
        MinDistance = MaxInt;
        for (i = 0; i < Projectiles.Length; ++i)
        {
            if (Projectiles[i].Class == ProjectileClass && Indices[i] == Index)
            {
                Distance = VSize(SearchLocation - Projectiles[i].Location);
                if (Distance < MinDistance)
                {
                    MinDistance = Distance;
                    MatchedIndex = i;
                }
                else
                {
                    break;
                }
            }
        }
        if (MatchedIndex > -1)
        {
            P = Projectiles[MatchedIndex];
            P.bNoFX = true;
            InternalRemove(MatchedIndex);
        }
    }
    return P;
}

simulated function Projectile MatchProjectileClass(Vector SearchLocation,
                                                   class<Projectile> ProjectileClass)
{
    local Projectile P;
    local float MinDistance;
    local float Distance;
    local int MatchedIndex;
    local int i;

    if (Projectiles.Length > 0)
    {
        MatchedIndex = -1;
        MinDistance = MaxInt;
        for (i = 0; i < Projectiles.Length; ++i)
        {
            if (Projectiles[i].Class != ProjectileClass)
            {
            }
            else
            {
                Distance = VSize(SearchLocation - Projectiles[i].Location);
                if (Distance < MinDistance)
                {
                    MinDistance = Distance;
                    MatchedIndex = i;
                }
                else
                {
                    break;
                }
            }
        }
        if (MatchedIndex > -1)
        {
            P = Projectiles[MatchedIndex];
            P.bNoFX = true;
            InternalRemove(MatchedIndex);
        }
    }
    return P;
}

simulated function Projectile MatchProjectile(Vector SearchLocation)
{
    local Projectile P;
    local float Distance;
    local int i;

    if (Projectiles.Length > 0)
    {

        Distance = VSize(SearchLocation - Projectiles[0].Location);
        for (i = 1; i < Projectiles.Length; ++i)
        {
            if (VSize(SearchLocation - Projectiles[i].Location) > Distance)
            {
                break;
            }
        }
        --i;
        P = Projectiles[i];
        P.bNoFX = true;
        InternalRemove(i);
    }
    return P;
}

simulated function bool RemoveProjectile(Projectile P)
{
    local int i;

    for (i = 0; i < Projectiles.Length; ++i)
    {
        if (Projectiles[i] == P)
        {
            InternalRemove(i);
            return true;
        }
    }
    return false;
}

simulated function PruneProjectiles()
{
    local int i;

    for (i = Projectiles.Length - 1; i >= 0; --i)
    {
        if (Projectiles[i] == None)
        {
            InternalRemove(i);
        }
    }
}

simulated function Projectile TrackProjectile(Projectile P, optional int Index)
{
    Projectiles[Projectiles.Length] = P;
    Indices[Indices.Length] = Index;
    return P;
}

simulated private function InternalRemove(int Index)
{
    Projectiles[Index].SetPropertyText("bRemoved", "true");
    Projectiles.Remove(Index, 1);
    Indices.Remove(Index, 1);
}

defaultproperties
{
}
