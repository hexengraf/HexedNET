class HxNTWeaponInfo extends Object;

var class<Weapon> WeaponClass;
var HxRandomGenerator Generator;
var private array<Projectile> PredProjectiles;
var private array<int> Indices;

function RefreshSeed(HxRandomGeneratorAlt Seeder)
{
    Generator.SetSeed(Seeder.RandInt(), Seeder.RandInt(), Seeder.RandInt(), Seeder.RandInt());
}

function Projectile MatchPrediction(Projectile AuthProjectile,
                                    class<Projectile> ProjectileClass,
                                    optional int Index)
{
    local Projectile P;
    local float MinDistance;
    local float Distance;
    local int MatchedIndex;
    local int i;

    PrunePredictedProjectiles();
    MatchedIndex = -1;
    MinDistance = MaxInt;
    for (i = 0; i < PredProjectiles.Length; ++i)
    {
        if (PredProjectiles[i].Class == ProjectileClass && Indices[i] == Index)
        {
            Distance = VSize(AuthProjectile.Location - PredProjectiles[i].Location);
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
        P = PredProjectiles[MatchedIndex];
        P.bNoFX = true;
        InternalRemove(MatchedIndex);
    }
    return P;
}

function Projectile AddPredictedProjectile(Projectile P, optional int Index)
{
    PredProjectiles[PredProjectiles.Length] = P;
    Indices[Indices.Length] = Index;
    return P;
}

function bool RemovePredictedProjectile(Projectile P)
{
    local int i;

    for (i = 0; i < PredProjectiles.Length; ++i)
    {
        if (PredProjectiles[i] == P)
        {
            InternalRemove(i);
            return true;
        }
    }
    return false;
}

private function PrunePredictedProjectiles()
{
    local int i;

    for (i = PredProjectiles.Length - 1; i >= 0; --i)
    {
        if (PredProjectiles[i] == None)
        {
            PredProjectiles.Remove(i, 1);
        }
    }
}

private function InternalRemove(int Index)
{
    PredProjectiles[Index].SetPropertyText("bRemoved", "true");
    PredProjectiles.Remove(Index, 1);
    Indices.Remove(Index, 1);
}

defaultproperties
{
}
