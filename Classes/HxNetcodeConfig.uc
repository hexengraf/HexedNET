class HxNetcodeConfig extends HxConfig
    config(User)
    PerObjectConfig;

var config bool bPingCompensation;
var config float PingFrequency;
var config float PingSmoothing;

defaultproperties
{
    ObjectName="HexedNET"
    Properties(0)=(Name="bPingCompensation",Type=HX_PROPERTY_Bool)
    Properties(1)=(Name="PingFrequency",Type=HX_PROPERTY_Float,LowerLimit="0.2",UpperLimit="20.0")
    Properties(2)=(Name="PingSmoothing",Type=HX_PROPERTY_Float,LowerLimit="0.05",UpperLimit="1.0")
    DisplayInfo(0)=(Caption="Enable Ping Compensation",Hint="Enable ping compensation for weapons.")
    DisplayInfo(1)=(Caption="Ping Frequency",Hint="Frequency to send pings (pings/second).",Step="0.25",bAdvanced=true)
    DisplayInfo(2)=(Caption="Ping Smoothing Factor",Hint="Factor to smooth out ping spikes from the average. Use low values for high smoothing (1.0 disables averaging completely).",Step="0.05",bAdvanced=true)

    bPingCompensation=true
    PingFrequency=2.0
    PingSmoothing=0.3
}
