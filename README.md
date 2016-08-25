# FHEM-TPLink-HS110
Perl command line tool and FHEM-module for the TP-Link HS100/HS110 wifi controlled power outlet

## 24_TPLinkHS110.pm
t.b.d.

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


