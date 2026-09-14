class HxNet_RocketProjPredicted extends RocketProj;

var HxNTWeaponInfo WeaponInfo;
var bool bRemoved;

simulated event Destroyed()
{
    if (!bRemoved && WeaponInfo != None)
    {
        WeaponInfo.RemoveProjectile(Self);
    }
    Super.Destroyed();
}

simulated function PostNetBeginPlay()
{
    local PlayerController PC;

    Super(Projectile).PostNetBeginPlay();
    if (Level.bDropDetail || Level.DetailMode == DM_Low)
    {
        bDynamicLight = false;
        LightType = LT_None;
    }
    else
    {
        PC = Level.GetLocalPlayerController();
        if ((Instigator == None || PC != Instigator.Controller)
            && (PC == None || PC.ViewTarget == None
                || VSize(PC.ViewTarget.Location - Location) > 3000))
        {
            bDynamicLight = false;
            LightType = LT_None;
        }
    }
}

function BlowUp(Vector HitLocation)
{
}

defaultproperties
{
    bNetTemporary=false
}
