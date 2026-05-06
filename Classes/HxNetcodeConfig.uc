class HxNetcodeConfig extends HxConfig
    config(User)
    PerObjectConfig;

var config bool bEnhancedNetcode;
var config float PingFrequency;
var config float PingSmoothing;

defaultproperties
{
    ObjectName="HexedNET"
    Properties(0)=(Name="bEnhancedNetcode",Type=HX_PROPERTY_Bool)
    Properties(1)=(Name="PingFrequency",Type=HX_PROPERTY_Float,LowerLimit="0.2",UpperLimit="20.0")
    Properties(2)=(Name="PingSmoothing",Type=HX_PROPERTY_Float,LowerLimit="0.05",UpperLimit="1.0")
    DisplayInfo(0)=(Caption="Enable enhanced netcode",Hint="Enable enhanced netcode on weapons.")
    DisplayInfo(1)=(Caption="Ping frequency",Hint="Frequency to send pings (pings/second).",Step="0.25",bAdvanced=true)
    DisplayInfo(2)=(Caption="Ping smoothing factor",Hint="Factor to smooth out ping spikes from the average. Use low values for high smoothing (1.0 disables averaging completely).",Step="0.05",bAdvanced=true)

    bEnhancedNetcode=true
    PingFrequency=1.5
    PingSmoothing=0.3
}
