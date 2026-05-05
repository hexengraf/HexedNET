class HxNTUserConfig extends HxConfig
    config(User)
    PerObjectConfig;

var config bool bEnhancedNetcode;

defaultproperties
{
    ObjectName="HexedNET"
    Properties(0)=(Name="bEnhancedNetcode",Type=HX_PROPERTY_Bool)
    DisplayInfo(0)=(Section="Enhanced Netcode",Caption="Enable Enhanced Netcode",Hint="Enable enhanced netcode on weapons.")

    bEnhancedNetcode=true
}
