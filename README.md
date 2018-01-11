Release 2018-11-01 SetExtension

# FHEM-TPLink-HS110
Perl command line tool and FHEM-module for the TP-Link HS100/HS110 wifi controlled power outlet.

In the subfolder "Loxone" you'll find a derived module for Loxone.

## 24_TPLinkHS110.pm
  <b>Define</b>
    <code>define &lt;name&gt; TPLinkHS110 &lt;ip/hostname&gt;</code><br>
        <br>
        Defines a TP-Link HS100 or HS110 wifi-controlled switchable power outlet.<br>
        The difference between HS100 and HS110 is, that the HS110 provides realtime measurments of<br>
        power, current and voltage.<br>
        This module automatically detects the modul defined and adapts the readings accordingly.<br>
        <br><br>
        This module does not implement all functions of the HS100/110.<br>
        Currently, all parameters relevant for running the outlet under FHEM are processed.<br>
        Writeable are only "On", "Off" and the nightmode (On/Off) (Nightmode: the LEDs of the outlet are switched off).<br>
        Further programming of the outlet should be done by TPLinks app "Kasa", which funtionality is partly redundant<br>
        with FHEMs core functions.
  <p>
  <b>Attributs</b>
        <ul>
                <li><b>interval</b>: The interval in seconds, after which FHEM will update the current measurements. Default: 300s</li>
                        An update of the measurements is done on each switch (On/Off) as well.
                <p>
                <li><b>timeout</b>:  Timeout in seconds used while communicationg with the outlet. Default: 1s</li>
                        <i>Warning:</i>: the timeout of 1s is chosen fairly aggressive. It could lead to errors, if the outlet is not answerings the requests
                        within this timeout.<br>
                        Please consider, that raising the timeout could mean blocking the whole FHEM during the timeout!
                <p>
                <li><b>disable</b>: The execution of the module is suspended. Default: no.</li>
                        <i>Warning: if your outlet is not on or not connected to the wifi network, consider disabling this module
                        by the attribute "disable". Otherwise the cyclic update of the outlets measurments will lead to blockings in FHEM.</i>
        </ul>
  <p>
  <b>Requirements</b>
        <ul>
        This module uses the follwing perl-modules:<br><br>
        <li> Perl Module: IO::Socket::INET </li>
        <li> Perl Module: IO::Socket::Timeout </li>
        </ul>


## tplink_hs110_cmd.pl
This is a command line tool to control the TP-Link HS100/HS110 wifi controlled power outlet.
It requires perl and some common perl modules.

This implements many commands but not all.
The program is focused on querying most of the data the HS100/110 does provide.
Tough it can only turn it on and off and enable/disabled the nightmode.
You can't set things like schedule, wifi network etc.
Use the (not so bad at all) smartphone app for this.
If you want to implement more commands, see tplink-smarthome-commands.txt for a full list
and submit your changes as a pull request to my github repository.

It's a good tool to setup and debug 24_TPLinkHS110.pm

Use it at your own risk!


