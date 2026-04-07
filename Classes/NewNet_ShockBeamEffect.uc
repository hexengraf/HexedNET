class NewNet_ShockBeamEffect extends ShockBeamEffect;

var class<ShockBeamEffect> ExtraBeamClass;

function AimAt(Vector hl, Vector hn)
{
    if (bNetOwner && Level.NetMode == NM_Client)
    {
        return;
    }
    Super.AimAt(hl,hn);
}

simulated function PostBeginPlay()
{
    if (bNetOwner && Level.NetMode == NM_Client)
    {
        return;
    }
    Super.PostBeginPlay();
}

simulated function PostNetBeginPlay()
{
    local PLayerController PC;

    Super.PostNetBeginPlay();
    if(Level.NetMode == NM_Client)
    {
        PC = Level.GetLocalPlayerController();
        if (PC != None && PC.Pawn != None && PC.Pawn == Instigator)
        {
            Destroy();
        }
    }
}

simulated function SpawnEffects()
{
    local PLayerController PC;
    local xWeaponAttachment Attachment;
    local ShockBeamCoil Coil;
    local ShockBeamEffect ExtraCoil;
    local Vector EffectLoc;

    if (Level.NetMode == NM_Client)
    {
        PC = Level.GetLocalPlayerController();
        if(PC != None && PC.Pawn != None && PC.Pawn == Instigator)
        {
            return;
        }
    }
    if (Instigator != None)
    {
        if (Instigator.IsFirstPerson())
        {
            if (Instigator.Weapon != None && Instigator.Weapon.Instigator == Instigator)
            {
                SetLocation(Instigator.Weapon.GetEffectStart());
            }
            else
            {
                SetLocation(Instigator.Location);
            }
            Spawn(MuzFlashClass,,, Location);
        }
        else
        {
            Attachment = xPawn(Instigator).WeaponAttachment;
            if (Attachment != None && (Level.TimeSeconds - Attachment.LastRenderTime) < 1)
            {
                SetLocation(Attachment.GetTipLocation());
            }
            else
            {
                SetLocation(
                    Instigator.Location + Instigator.EyeHeight * Vect(0,0,1)
                    + Normal(mSpawnVecA - Instigator.Location) * 25.0);
            }
            Spawn(MuzFlash3Class);
        }
    }
    EffectLoc = mSpawnVecA + HitNormal * 2;
    if (EffectIsRelevant(EffectLoc, false) && HitNormal != Vect(0,0,0))
    {
        SpawnImpactEffects(Rotator(HitNormal), EffectLoc);
    }
    if ((Instigator != None && Instigator.IsFirstPerson())
        || (!Level.bDropDetail && Level.DetailMode != DM_Low && VSize(Location - mSpawnVecA) > 40
            && !Level.GetLocalPlayerController().BeyondViewDistance(Location, 0)))
    {
        Coil = Spawn(CoilClass,Owner,, Location, Rotation);
        if (Coil != None)
        {
            Coil.bOwnerNoSee = True;
            Coil.mSpawnVecA = mSpawnVecA;
        }
    }
    if (ExtraBeamClass != None)
    {
        ExtraCoil = Spawn(ExtraBeamClass, Owner);
        if (ExtraCoil != None)
        {
            ExtraCoil.bOwnerNoSee = true;
            ExtraCoil.AimAt(mSpawnVecA, HitNormal);
        }
    }
}

defaultproperties
{
}
