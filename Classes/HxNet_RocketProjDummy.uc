class HxNet_RocketProjDummy extends RocketProj;

var int Index;

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
