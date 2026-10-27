class HxNetcodeConfig extends HxConfig
    config(User)
    PerObjectConfig;

var config bool bLagCompensation;
var localized const string  MillisecondsSuffix;

var private HxNTClient Client;

function InitializeProperties()
{
    if (ClientManager.IsFirstRun())
    {
        // TODO: remove this in v11
        ClearConfig();
        bLagCompensation = default.bLagCompensation;
        SaveConfig();
    }
    EqualizeWeaponConfigOverrides();
    class'MutHexedNET'.static.ApplyFireModeOverrides();
    class'HxNTClient'.default.bLagCompensation = bLagCompensation;
}

function ApplyProperty(int Index)
{
    switch (Index)
    {
        case 0:
            class'HxNTClient'.default.bLagCompensation = bLagCompensation;
            ClientManager.RefreshConfigurationMenu();
            break;
    }
    if (HasClient())
    {
        Client.InitializeCompensation();
    }
}

function bool ResetProperty(int Index)
{
    switch (Index)
    {
        case 0:
            bLagCompensation = default.bLagCompensation;
            class'HxNTClient'.default.bLagCompensation = bLagCompensation;
            ClientManager.RefreshConfigurationMenu();
            return true;
    }
    return false;
}

function bool ShouldShowStatus(int Index)
{
    return bLagCompensation && HasClient();
}

function string GetStatus(int Index)
{
    if (HasClient())
    {
        switch (Index)
        {
            case 0:
                return int(Round(Client.GetAveragePing() * 1000))$MillisecondsSuffix;
        }
    }
    return "";
}

function bool HasClient()
{
    if (Client == None)
    {
        foreach Level.DynamicActors(class'HxNTClient', Client) break;
    }
    return Client != None;
}

function Destroy()
{
    Client = None;
    EqualizeWeaponConfigOverrides();
    class'MutHexedNET'.static.RestoreFireModeOverrides();
    Super.Destroy();
}

static function EqualizeWeaponConfigOverrides()
{
    local int i;

    for (i = 0; i < class'MutHexedNET'.default.ClassOverrides.Length; ++i)
    {
        if (class'MutHexedNET'.default.ClassOverrides[i].NETClass != None)
        {
            EqualizeWeaponConfigs(
                class'MutHexedNET'.default.ClassOverrides[i].TargetClass,
                class'MutHexedNET'.default.ClassOverrides[i].NETClass);
        }
    }
    EqualizeWeaponConfigs(class'ShockRifle', class'HxSuperShockRifle');
    EqualizeWeaponConfigs(class'ShockRifle', class'HxZoomSuperShockRifle');
}


defaultproperties
{
    Properties(0)=(Name="bLagCompensation",Type=HX_PROPERTY_Bool)
    DisplayInfo(0)=(Caption="Enable Lag Compensation",Hint="Enable lag compensation.")
    StatusInfo(0)=(Caption="Average Ping")
    bLagCompensation=true
    MillisecondsSuffix=" ms"
}
