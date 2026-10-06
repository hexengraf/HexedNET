class HxNetcodeConfig extends HxConfig
    config(User)
    PerObjectConfig;

var config bool bLagCompensation;

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
    class'HxNTClient'.default.bLagCompensation = bLagCompensation;
}

function ApplyProperty(int Index)
{
    switch (Properties[Index].Name)
    {
        case "bLagCompensation":
            class'HxNTClient'.default.bLagCompensation = bLagCompensation;
            break;
    }
    if (HasClient())
    {
        Client.InitializeCompensation();
    }
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
    Super.Destroy();
}

defaultproperties
{
    Properties(0)=(Name="bLagCompensation",Type=HX_PROPERTY_Bool)
    DisplayInfo(0)=(Caption="Enable Lag Compensation",Hint="Enable lag compensation.")
    bLagCompensation=true
}
