class HxNet_LinkFire extends LinkFire;

var private MutHexedNET HexedNET;
var private HxNTClient Client;

function PreBeginPlay()
{
    Super.PreBeginPlay();
    class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client);
}

function bool WantsPingCompensation()
{
    return class'HxNTWeapon'.static.ValidateClient(Level, HexedNET, Instigator, Client)
        && Client.WantsPingCompensation();
}

simulated function ModeTick(float DT)
{
    local Vector PawnHitLocation;
    local Vector StartTrace;
    local Vector EndTrace;
    local Vector HitLocation;
    local Vector HitNormal;
    local Vector EndEffect;
    local Vector X;
    local Vector Y;
    local Vector Z;
    local Actor Other;
    local Rotator Aim;
    local LinkGun LinkGun;
    local float ls;
    local bool bIsHealingObjective;
    local int AdjustedDamage;
    local DestroyableObjective HealObjective;
    local Vehicle LinkedVehicle;

    if (Instigator.Role < Role_Authority || !WantsPingCompensation() || !bIsFiring)
    {
        Super.ModeTick(DT);
        return;
    }
    LinkGun = LinkGun(Weapon);
    LinkGun.Links = Max(0, LinkGun.Links);
    ls = LinkScale[Min(LinkGun.Links, 5)];
    if (myHasAmmo(LinkGun) && (UpTime > 0.0 || Instigator.Role < ROLE_Authority))
    {
        UpTime -= DT;
        LinkGun.GetViewAxes(X, Y, Z);
        StartTrace = GetFireStart(X, Y, Z);
        TraceRange = default.TraceRange + LinkGun.Links * 250;
        if (Instigator.Role < ROLE_Authority)
        {
            if (Beam == None)
            {
                Beam = FindLinkBeam();
            }
            if (Beam != None)
            {
                LockedPawn = Beam.LinkedPawn;
            }
        }
        if (LockedPawn != None)
        {
            TraceRange *= 1.5;
        }
        if (Instigator.Role == ROLE_Authority && bDoHit)
        {
            LinkGun.ConsumeAmmo(ThisModeNum, AmmoPerFire);
        }
        if (LockedPawn != None)
        {
            EndTrace = LockedPawn.Location + LockedPawn.BaseEyeHeight * Vect(0, 0, 0.5);
            if (Instigator.Role == ROLE_Authority)
            {
                if (Normal(EndTrace - StartTrace) dot X < LinkFlexibility || LockedPawn.Health <= 0
                    || LockedPawn.bDeleteMe || VSize(EndTrace - StartTrace) > 1.5 * TraceRange)
                {
                    SetLinkTo(None);
                }
            }
        }
        if (LockedPawn == None)
        {
            Aim = GetPlayerAim(StartTrace, AimError);
            X = Vector(Aim);
            EndTrace = StartTrace + TraceRange * X;
        }
        HexedNET.Rewind(Client.GetCompensationTime());
        Other = HexedNET.RewoundTrace(Weapon, HitLocation, HitNormal, EndTrace, StartTrace);
        HexedNET.UndoRewind();
        if (Other != None && Other != Instigator)
        {
            EndEffect = HitLocation;
        }
        else
        {
            EndEffect = EndTrace;
        }
        if (Beam != None)
        {
            Beam.EndEffect = EndEffect;
        }
        if (Instigator.Role < ROLE_Authority)
        {
            if (LinkGun.ThirdPersonActor != None)
            {
                if (LinkGun.Linking
                    || (Other != None && Instigator.PlayerReplicationInfo.Team != None
                        && Other.TeamLink(Instigator.PlayerReplicationInfo.Team.TeamIndex)))
                {
                    SetLinkTeamColor();
                }
                else
                {
                    SetLinkColor();
                }
            }
            return;
        }
        if (Other != None && Other != Instigator)
        {
            // target can be linked to
            if (IsLinkable(Other))
            {
                if (Other != LockedPawn)
                {
                    SetLinkTo(Pawn(Other));
                }
                if (LockedPawn != None)
                {
                    LinkBreakTime = LinkBreakDelay;
                }
            }
            else
            {
                // stop linking
                if (LockedPawn != None)
                {
                    if (LinkBreakTime <= 0.0)
                    {
                        SetLinkTo(None);
                    }
                    else
                    {
                        LinkBreakTime -= DT;
                    }
                }
                // beam is updated every frame, but damage is only done based on the firing rate
                if (bDoHit)
                {
                    if (Beam != None)
                    {
                        Beam.bLockedOn = false;
                    }
                    Instigator.MakeNoise(1.0);
                    AdjustedDamage = AdjustLinkDamage(LinkGun, Other, Damage);
                    if (!Other.bWorldGeometry)
                    {
                        if (Level.Game.bTeamGame && Pawn(Other) != None
                            && Pawn(Other).PlayerReplicationInfo != None
                            && Pawn(Other).PlayerReplicationInfo.Team == Instigator.PlayerReplicationInfo.Team)
                        {
                            // so even if friendly fire is on you can't hurt teammates
                            AdjustedDamage = 0;
                        }
                        HealObjective = DestroyableObjective(Other);
                        if (HealObjective == None)
                        {
                            HealObjective = DestroyableObjective(Other.Owner);
                        }
                        if (HealObjective != None && HealObjective.TeamLink(Instigator.GetTeamNum()))
                        {
                            SetLinkTo(None);
                            bIsHealingObjective = true;
                            if (!HealObjective.HealDamage(
                                AdjustedDamage, Instigator.Controller, DamageType))
                            {
                                LinkGun.ConsumeAmmo(ThisModeNum, -AmmoPerFire);
                            }
                        }
                        else
                        {
                            Other.TakeDamage(
                                AdjustedDamage,
                                Instigator,
                                PawnHitLocation,
                                MomentumTransfer * X,
                                DamageType);
                        }
                        if (Beam != None)
                        {
                            Beam.bLockedOn = true;
                        }
                    }
                }
            }
        }
        // vehicle healing
        LinkedVehicle = Vehicle(LockedPawn);
        if (LinkedVehicle != None && bDoHit)
        {
            AdjustedDamage = Damage * (1.5 * Linkgun.Links + 1) * Instigator.DamageScaling;
            if (Instigator.HasUDamage())
            {
                AdjustedDamage *= 2;
            }
            if (!LinkedVehicle.HealDamage(AdjustedDamage, Instigator.Controller, DamageType))
            {
                LinkGun.ConsumeAmmo(ThisModeNum, -AmmoPerFire);
            }
        }
        LinkGun.Linking = LockedPawn != None || bIsHealingObjective;
        // beam effect is created and destroyed when firing starts and stops
        if (Beam == None && bIsFiring)
        {
            Beam = Weapon.Spawn(BeamEffectClass, Instigator);
            // vary link volume to make sure it gets replicated
            // (in case owning player changed it client side)
            if (SentLinkVolume == Default.LinkVolume)
            {
                SentLinkVolume = Default.LinkVolume + 1;
            }
            else
            {
                SentLinkVolume = Default.LinkVolume;
            }
        }
        if (Beam != None)
        {
            if (LinkGun.Linking
                || (Other != None && Instigator.PlayerReplicationInfo.Team != None
                    && Other.TeamLink(Instigator.PlayerReplicationInfo.Team.TeamIndex)))
            {
                Beam.LinkColor = Instigator.PlayerReplicationInfo.Team.TeamIndex + 1;
                if (LinkGun.ThirdPersonActor != None)
                {
                    SetLinkTeamColor();
                }
            }
            else
            {
                Beam.LinkColor = 0;
                if (LinkGun.ThirdPersonActor != None)
                {
                    SetLinkColor();
                }
            }
            Beam.Links = LinkGun.Links;
            Instigator.AmbientSound = BeamSounds[Min(Beam.Links, 3)];
            Instigator.SoundVolume = SentLinkVolume;
            Beam.LinkedPawn = LockedPawn;
            Beam.bHitSomething = Other != None;
            Beam.EndEffect = EndEffect;
        }
    }
    else
    {
        StopFiring();
    }
    bStartFire = false;
    bDoHit = false;
}

function LinkBeamEffect FindLinkBeam()
{
    local LinkBeamEffect B;

    foreach Weapon.DynamicActors(class'LinkBeamEffect', B)
    {
        if (!B.bDeleteMe && B.Instigator != None && B.Instigator == Instigator)
        {
            break;
        }
    }
    return B;
}

function SetLinkTeamColor()
{
    if (Instigator.PlayerReplicationInfo.Team == None
        || Instigator.PlayerReplicationInfo.Team.TeamIndex == 0)
    {
        LinkAttachment(Weapon.ThirdPersonActor).SetLinkColor(LC_Red);
    }
    else
    {
        LinkAttachment(Weapon.ThirdPersonActor).SetLinkColor(LC_Blue);
    }
}

function SetLinkColor()
{
    if (LinkGun(Weapon).Links > 0)
    {
        LinkAttachment(Weapon.ThirdPersonActor).SetLinkColor(LC_Gold);
    }
    else
    {
        LinkAttachment(Weapon.ThirdPersonActor).SetLinkColor(LC_Green);
    }
}

defaultproperties
{
}
