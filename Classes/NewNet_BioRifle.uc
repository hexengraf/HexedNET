class NewNet_BioRifle extends BioRifle
    HideDropDown
    CacheExempt;

var int CurIndex;

var private bool bConfigCleared;

replication
{
    unreliable if (Role == Role_Authority && bNetOwner)
        CurIndex;
}

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    if (Level.NetMode != NM_DedicatedServer)
    {
        if (!default.bConfigCleared)
        {
            ClearConfig();
            default.bConfigCleared = true;
        }
        class'HxNTWeapon'.static.ForceBaseClassConfig(Self, class'BioRifle');
    }
}

DefaultProperties
{
    FireModeClass(0)=class'NewNet_BioFire'
    FireModeClass(1)=class'NewNet_BioChargedFire'
}
