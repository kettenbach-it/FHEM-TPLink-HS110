################################################################
# $Id: 24_TPLinkHLB1x0.pm 19095 2019-04-02 13:02:04Z vk $
#
#  Release 2019-06-01 First Release
#
#  Copyright notice
#
#  (c) 2019 Copyright: Volker Kettenbach
#  e-mail: volker at kettenbach minus it dot de
#
#  Description:
#  This is an FHEM-Module for the TP Link TPLinkH LB100/110/120/130
#
#  Requirements
#  	Perl Module: IO::Socket::INET
#  	Perl Module: IO::Socket::Timeout
#  	
#  	In recent debian based distributions IO::Socket::Timeout can
#  	be installed by "apt-get install libio-socket-timeout-perl"
#  	In older distribution try "cpan IO::Socket::Timeout"
#
#  Origin:
#  https://gitlab.com/volkerkettenbach/FHEM-TPLink-Kasa
#
################################################################

package main;

use strict;
use warnings;
use IO::Socket::INET;
use IO::Socket::Timeout;
use bytes;
use JSON qw( decode_json );
use DateTime;
use SetExtensions;
use Data::Dumper;


#####################################
sub TPLinkLB1x0_Initialize($) {
	my ($hash) = @_;

	$hash->{DefFn} = "TPLinkLB1x0_Define";
	$hash->{ReadFn} = "TPLinkLB1x0_Get";
	$hash->{SetFn} = "TPLinkLB1x0_Set";
	$hash->{UndefFn} = "TPLinkLB1x0_Undefine";
	$hash->{DeleteFn} = "TPLinkLB1x0_Delete";
	$hash->{AttrFn} = "TPLinkLB1x0_Attr";
	$hash->{AttrList} = "interval " .
		"disable:0,1 " .
		"timeout " .
		"$readingFnAttributes";
}

#####################################
sub TPLinkLB1x0_Define($$) {
	my ($hash, $def) = @_;
	my $name = $hash->{NAME};

	my @a = split("[ \t][ \t]*", $def);
	return "Wrong syntax: use define <name> TPLinkLB1x0 <hostname/ip> " if (int(@a) != 3);

	$hash->{INTERVAL} = 300;
	$hash->{TIMEOUT} = 1;
	$hash->{HOST} = $a[2];
	$attr{$name}{"disable"} = 0;
	# initial request after 2 secs, there timer is set to interval for further update
	InternalTimer(gettimeofday() + 2, "TPLinkLB1x0_Get", $hash, 0);

	Log3 $hash, 3, "TPLinkLB1x0: $name defined.";

	return undef;
}

  
#####################################
sub TPLinkLB1x0_Get($$) {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my ($success, $json, $realtimejson);
	return "Device disabled in config" if ($attr{$name}{"disable"} eq "1");
	RemoveInternalTimer($hash);
	InternalTimer(gettimeofday() + $hash->{INTERVAL}, "TPLinkLB1x0_Get", $hash, 1);
	$hash->{NEXTUPDATE} = localtime(gettimeofday() + $hash->{INTERVAL});

	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
	$mon++;
	$year += 1900;

	my $errmsg;
	my $data;

	my $command = '{"system":{"get_sysinfo":{}}}';
	($errmsg, $data) = TPLinkLB1x0_SendCommand($hash, $command);
	if (defined($errmsg)) {
		Log3 $hash, 1, "TPLinkLB1x0: $name Get failed - " . $errmsg; # JV
		return;
	}

	readingsBeginUpdate($hash);

	($success, $json) = TPLinkLB1x0__evaljson($name, $data);
	if (!$success) {
		Log3 $hash, 1, "TPLinkLB1x0: $name Get failed"; # JV
		readingsEndUpdate($hash, 1);
		return;
	}

	Log3 $hash, 3, "TPLinkLB1x0: $name Get called. Relay state: $json->{'system'}->{'get_sysinfo'}->{'relay_state'}, RSSI: $json->{'system'}->{'get_sysinfo'}->{'rssi'}";

	my $hw_ver = $json->{'system'}->{'get_sysinfo'}->{'hw_ver'};
	my %hwMap = hwMapping();

	foreach my $key (sort keys %{$json->{'system'}->{'get_sysinfo'}}) {
		my $sysinfoValue = $json->{'system'}->{'get_sysinfo'}->{$key};

		#adjust different hw_ver readings 
		if (exists($hwMap{$hw_ver}{'system'}{'get_sysinfo'}{$key})) {
			if (exists($hwMap{$hw_ver}{'system'}{'get_sysinfo'}{$key}{'factor'})) {
				$sysinfoValue = $sysinfoValue * $hwMap{$hw_ver}{'system'}{'get_sysinfo'}{$key}{'factor'};
			}
			$key = $hwMap{$hw_ver}{'system'}{'get_sysinfo'}{$key}{'name'}
		}
		readingsBulkUpdate($hash, $key, $sysinfoValue);
	}
	if ($json->{'system'}->{'get_sysinfo'}->{'relay_state'} == 0) {
		readingsBulkUpdate($hash, "state", "off");
	}
	if ($json->{'system'}->{'get_sysinfo'}->{'relay_state'} == 1) {
		readingsBulkUpdate($hash, "state", "on");
	}
	# If the device is a HS110, get realtime data:
	#  if ( 1 == 0 ) {
	if ($json->{'system'}->{'get_sysinfo'}->{'model'} eq "HS110(EU)" or $json->{'system'}->{'get_sysinfo'}->{'model'} eq "HS110(UK)") {
		my $realtimejcommand = '{"emeter":{"get_realtime":{}}}';
		my $rdata;
		($errmsg, $rdata) = TPLinkLB1x0_SendCommand($hash, $realtimejcommand);
		if (defined($errmsg)) {
			Log3 $hash, 1, "TPLinkLB1x0: $name Get realtime data failed - " . $errmsg; # JV
			readingsEndUpdate($hash, 1);
			return;
		}

		if (length($rdata) == 0) {
			Log3 $hash, 1, "TPLinkLB1x0: $name: Received zero bytes of realtime data. Cannot process realtime data";
			readingsEndUpdate($hash, 1);
			return;
		}

		($success, $realtimejson) = TPLinkLB1x0__evaljson($name, $rdata);
		if (!$success) {
			Log3 $hash, 1, "TPLinkLB1x0: $name: Received zero bytes of realtime data. Cannot process realtime data";
			readingsEndUpdate($hash, 1);
			return;
		}
		else {
			Log3 $hash, 2, "TPLinkLB1x0: $name Realtime data updated";
		}

		my %emeterReadings = ();

		foreach my $key2 (sort keys %{$realtimejson->{'emeter'}->{'get_realtime'}}) {

			my $emeterValue = $realtimejson->{'emeter'}->{'get_realtime'}->{$key2};

			#adjust different hw_ver readings, be sure to list all emeter readings in hwMapping
			if (exists($hwMap{$hw_ver}{'emeter'}{'get_realtime'}{$key2})) {
				if (exists($hwMap{$hw_ver}{'emeter'}{'get_realtime'}{$key2}{'factor'})) {
					$emeterValue = $emeterValue * $hwMap{$hw_ver}{'emeter'}{'get_realtime'}{$key2}{'factor'};
				}
				$key2 = $hwMap{$hw_ver}{'emeter'}{'get_realtime'}{$key2}{'name'};
				readingsBulkUpdate($hash, $key2, $emeterValue);
				$emeterReadings{$key2} = $emeterValue;
			}
			else {
				return "Check supported hw_ver of device: $hw_ver\n";
			}
		}

		Log3 $hash, 3, "TPLinkLB1x0: $name Device is an HS110. Got extra realtime data: $emeterReadings{'power'} Watt, $emeterReadings{'voltage'} Volt, $emeterReadings{'current'} Ampere";


		# Get Daily Stats
		$command = '{"emeter":{"get_daystat":{"month":' . $mon . ',"year":' . $year . '}}}';
		($errmsg, $data) = TPLinkLB1x0_SendCommand($hash, $command);
		if (defined($errmsg)) {
			Log3 $hash, 1, "TPLinkLB1x0: $name Get daily stats failed - " . $errmsg; # JV
			readingsEndUpdate($hash, 1);
			return;
		}

		Log3 $hash, 3, "TPLinkLB1x0: $name Updating daystat. Data: " . $data;

		($success, $json) = TPLinkLB1x0__evaljson($name, $data);
		if ($success && $json) {

			my $total = 0;
			foreach my $key (sort keys @{$json->{'emeter'}->{'get_daystat'}->{'day_list'}}) {
				foreach my $key2 ($json->{'emeter'}->{'get_daystat'}->{'day_list'}[$key]) {
					if ($hw_ver eq "1.0") {
						$total = $total + $key2->{'energy'};
						if ($key2->{'day'} == $mday) {
							readingsBulkUpdate($hash, "daily_total", sprintf("%.3f", $key2->{'energy'}));
						}
					}
					else {
						$total = $total + $key2->{'energy_wh'};
						if ($key2->{'day'} == $mday) {
							readingsBulkUpdate($hash, "daily_total", sprintf("%.3f", $key2->{'energy_wh'} * 0.001));
						}
					}

				}
			}
			my $count = 1;
			$count = @{$json->{'emeter'}->{'get_daystat'}->{'day_list'}};
			if ($hw_ver eq "1.0") {readingsBulkUpdate($hash, "monthly_total", $total);}
			if ($hw_ver eq "2.0") {readingsBulkUpdate($hash, "monthly_total", $total * 0.001);}
			if ($count) {readingsBulkUpdate($hash, "daily_average", $total / $count)};
			Log3 $hash, 2, "TPLinkLB1x0: $name Daystat updated";
		}
		else {
			Log3 $hash, 1, "TPLinkLB1x0: $name Error updating daystat. Success: " . $success . ", json: " . $json;
			Log3 $hash, 3, "TPLinkLB1x0: $name Updating readings";
			readingsEndUpdate($hash, 1);
			Log3 $hash, 3, "TPLinkLB1x0: $name Get end";
			return;
		}
	}
	Log3 $hash, 3, "TPLinkLB1x0: $name Updating readings";
	readingsEndUpdate($hash, 1);
	Log3 $hash, 3, "TPLinkLB1x0: $name Get end";
}


#####################################
sub TPLinkLB1x0_Set($$) {
	my ($hash, $name, $cmd, @args) = @_;
	my $cmdList = "on off";
	my ($success, $json, $realtimejson);
	return "\"set $name\" needs at least one argument" unless (defined($cmd));
	return if ($attr{$name}{"disable"} eq "1");
	Log3 $hash, 3, "TPLinkLB1x0: $name Set <" . $cmd . "> called" if ($cmd !~ /\?/);

	my $command = "";
	if ($cmd eq "on") {
		$command = '{"system":{"set_relay_state":{"state":1}}}';
	}
	elsif ($cmd eq "off") {
		$command = '{"system":{"set_relay_state":{"state":0}}}';
	}
	else # wenn der übergebene Befehl nicht durch X_Set() verarbeitet werden kann, Weitergabe an SetExtensions
	{
		return SetExtensions($hash, $cmdList, $name, $cmd, @args);
	}

	my $errmsg;
	my $data;

	($errmsg, $data) = TPLinkLB1x0_SendCommand($hash, $command);
	if (defined($errmsg)) {
		Log3 $hash, 1, "TPLinkLB1x0: $name Set failed - " . $errmsg;
		return;
	}

	readingsBeginUpdate($hash);

	($success, $json) = TPLinkLB1x0__evaljson($name, $data);
	if (!$success) {
		Log3 $hash, 1, "TPLinkLB1x0: $name Set failed - parsing";
		readingsEndUpdate($hash, 1);
		return;
	}

	if ($json->{'system'}->{'set_relay_state'}->{'err_code'} eq "0") {
		Log3 $hash, 3, "TPLinkLB1x0: $name Set OK - get status data";
		TPLinkLB1x0_Get($hash, "");

	}
	else {
		Log3 $hash, 1, "TPLinkLB1x0: $name Set failed with error code";
		return "Command failed!";
	}
	return undef;
}


#####################################
sub TPLinkLB1x0_Undefine($$) {
	my ($hash, $arg) = @_;
	my $name = $hash->{NAME};
	RemoveInternalTimer($hash);
	Log3 $hash, 3, "TPLinkLB1x0: $name undefined.";
	return;
}


#####################################
sub TPLinkLB1x0_Delete {
	my ($hash, $arg) = @_;
	my $name = $hash->{NAME};
	Log3 $hash, 3, "TPLinkLB1x0: $name deleted.";
	return undef;
}


#####################################
sub TPLinkLB1x0_Attr {
	my ($cmd, $name, $aName, $aVal) = @_;
	my $hash = $defs{$name};

	if ($aName eq "interval") {
		if ($cmd eq "set") {
			$hash->{INTERVAL} = $aVal;
		}
		else {
			$hash->{INTERVAL} = 300;
		}
		Log3 $hash, 3, "TPLinkLB1x0: $name INTERVAL set to " . $hash->{INTERVAL};
	}

	if ($aName eq "timeout") {
		if ($cmd eq "set") {
			$hash->{TIMEOUT} = $aVal;
		}
		else {
			$hash->{TIMEOUT} = 1;
		}
		Log3 $hash, 3, "TPLinkLB1x0: $name TIMEOUT set to " . $hash->{TIMEOUT};
	}
	return undef;
}







sub get_bulb_sysinfo{
	my $ip = shift;
	my %returnHash;
	my $command = '{"system":{"get_sysinfo":{}}}';
	my $returned = sendcmd($ip, "$command");
	$returnHash{'sw_ver'} = $returned->{'system'}{'get_sysinfo'}{'sw_ver'};
	$returnHash{'hw_ver'} = $returned->{'system'}{'get_sysinfo'}{'hw_ver'};
	$returnHash{'model'} = $returned->{'system'}{'get_sysinfo'}{'model'};
	$returnHash{'alias'} = $returned->{'system'}{'get_sysinfo'}{'alias'};
	$returnHash{'description'} = $returned->{'system'}{'get_sysinfo'}{'description'};
	$returnHash{'mic_type'} = $returned->{'system'}{'get_sysinfo'}{'mic_type'};
	$returnHash{'dev_state'} = $returned->{'system'}{'get_sysinfo'}{'dev_state'};
	$returnHash{'mic_mac'} = $returned->{'system'}{'get_sysinfo'}{'mic_mac'};
	$returnHash{'deviceId'} = $returned->{'system'}{'get_sysinfo'}{'deviceId'};
	$returnHash{'oemId'} = $returned->{'system'}{'get_sysinfo'}{'oemId'};
	$returnHash{'hwId'} = $returned->{'system'}{'get_sysinfo'}{'hwId'};
	$returnHash{'is_factory'} = $returned->{'system'}{'get_sysinfo'}{'is_factory'};
	$returnHash{'disco_ver'} = $returned->{'system'}{'get_sysinfo'}{'disco_ver'};
	$returnHash{'ctrl_protocols_name'} = $returned->{'system'}{'get_sysinfo'}{'ctrl_protocols'}{'name'};
	$returnHash{'ctrl_protocols_version'} = $returned->{'system'}{'get_sysinfo'}{'ctrl_protocols'}{'version'};
	$returnHash{'light_state_on_off'} = $returned->{'system'}{'get_sysinfo'}{'light_state'}{'on_off'};
	$returnHash{'light_state_mode'} = $returned->{'system'}{'get_sysinfo'}{'light_state'}{'mode'};
	$returnHash{'light_state_hue'} = $returned->{'system'}{'get_sysinfo'}{'light_state'}{'hue'};
	$returnHash{'light_state_saturation'} = $returned->{'system'}{'get_sysinfo'}{'light_state'}{'saturation'};
	$returnHash{'light_state_color_temp'} = $returned->{'system'}{'get_sysinfo'}{'light_state'}{'color_temp'};
	$returnHash{'light_state_brightness'} = $returned->{'system'}{'get_sysinfo'}{'light_state'}{'brightness'};
	$returnHash{'is_dimmable'} = $returned->{'system'}{'get_sysinfo'}{'is_dimmable'};
	$returnHash{'is_color'} = $returned->{'system'}{'get_sysinfo'}{'is_color'};
	$returnHash{'is_variable_color_temp'} = $returned->{'system'}{'get_sysinfo'}{'is_variable_color_temp'};

	### Seems like there's a better way to do this... don't care for now
	# print "preferred_state->\n";
	# my @prefArr = @{$returned->{'system'}{'get_sysinfo'}{'preferred_state'}};
	# foreach(@prefArr)
	# {
	# my %tmphash = %{$_};
	# print "\t";
	# $returnHash("preferred_state_index"} = $tmphash{index};
	# $returnHash("preferred_state_hue"} = $tmphash{hue};
	# $returnHash("preferred_state_saturation"} = $tmphash{saturation};
	# $returnHash("preferred_state_color_temp"} = $tmphash{color_temp};
	# $returnHash("preferred_state_brightness"} = $tmphash{brightness};
	# print "\n";
	# }

	$returnHash{'rssi'} = $returned->{'system'}{'get_sysinfo'}{'rssi'};
	$returnHash{'active_mode'} = $returned->{'system'}{'get_sysinfo'}{'active_mode'};
	$returnHash{'heapsize'} = $returned->{'system'}{'get_sysinfo'}{'heapsize'};
	$returnHash{'err_code'} = $returned->{'system'}{'get_sysinfo'}{'err_code'};
	return %returnHash;
}

#1 = on
#0 = off
#returns new status of light
sub set_bulb_state{
	my $ip = shift;
	my $status = shift;
	my $brightness = shift;
	my $transition = shift;
	my $extraparams = '';
	if(defined($brightness))
	{
		$extraparams = $extraparams . ',"ignore_default":1,"brightness":' . $brightness;
	}
	if(defined($transition))
	{
		$extraparams = $extraparams . ',"transition_period":' . $transition;
	}
	my $command = '{"smartlife.iot.smartbulb.lightingservice":{"transition_light_state":{"on_off":' . $status . $extraparams . '}}}';
	my $return = sendcmd($ip, "$command");
	my $reply = $return->{'smartlife.iot.smartbulb.lightingservice'}{'transition_light_state'}{'on_off'};
	return $reply;
}

#returns hash of state info
sub get_bulb_state{
	my $ip = shift;
	my $command = '{"smartlife.iot.smartbulb.lightingservice":{"get_light_state":{}}}';
	my $return = sendcmd($ip, "$command");
	my %reply;
	$reply{'on_off'} = $return->{'smartlife.iot.smartbulb.lightingservice'}{'get_light_state'}{'on_off'};
	$reply{'mode'} = $return->{'smartlife.iot.smartbulb.lightingservice'}{'get_light_state'}{'mode'};
	$reply{'hue'} = $return->{'smartlife.iot.smartbulb.lightingservice'}{'get_light_state'}{'hue'};
	$reply{'saturation'} = $return->{'smartlife.iot.smartbulb.lightingservice'}{'get_light_state'}{'saturation'};
	$reply{'color_temp'} = $return->{'smartlife.iot.smartbulb.lightingservice'}{'get_light_state'}{'color_temp'};
	$reply{'brightness'} = $return->{'smartlife.iot.smartbulb.lightingservice'}{'get_light_state'}{'brightness'};
	return %reply;
}

#only works if bulb is on
sub set_white_temp{
	my $ip = shift;
	my $temp = shift;
	my $command = '{"smartlife.iot.smartbulb.lightingservice":{"transition_light_state":{"color_temp":' . $temp . '}}}';
	my $return = sendcmd($ip, "$command");
	my $reply = $return->{'smartlife.iot.smartbulb.lightingservice'}{'transition_light_state'}{'color_temp'};
	return $reply;
}

#returns hash of state info
sub get_color_temp{
	my $ip = shift;
	my $command = '{"smartlife.iot.smartbulb.lightingservice":{"get_light_state":{}}}';
	my $return = sendcmd($ip, "$command");
	my $reply = $return->{'smartlife.iot.smartbulb.lightingservice'}{'get_light_state'}{'color_temp'};
	return $reply;
}

#HSV- h values 0-255, other 0-100 #imnocolorexpert so  #thismaybeincorrect
#returns hash of hsv
sub get_hsv{
	my $ip = shift;
	my %reply = get_bulb_state($ip);
	my %return;
	$return{'hue'} = $reply{'hue'};
	$return{'saturation'} = $reply{'saturation'};
	$return{'value'} = $reply{'brightness'};
	return %return;
}


sub set_hsv{
	my $ip = shift;
	my $h = shift;
	my $s = shift;
	my $v = shift;
	my $command = '{"smartlife.iot.smartbulb.lightingservice":{"transition_light_state":{"hue":' . $h . ',"saturation":' . $s . ',"brightness":' . $v . ',"color_temp":0}}}';
	my $return = sendcmd($ip, "$command");
	my %reply;
	$reply{'hue'} = $return->{'smartlife.iot.smartbulb.lightingservice'}{'transition_light_state'}{'hue'};
	$reply{'saturation'} = $return->{'smartlife.iot.smartbulb.lightingservice'}{'transition_light_state'}{'saturation'};
	$reply{'value'} = $return->{'smartlife.iot.smartbulb.lightingservice'}{'transition_light_state'}{'brightness'};
	return %reply;
}

sub set_bulb_red{
	my $ip = shift;
	set_hsv($ip, 0, 100, 100);
}

sub set_bulb_green{
	my $ip = shift;
	set_hsv($ip, 120, 100, 100);
}

sub set_bulb_blue{
	my $ip = shift;
	set_hsv($ip, 200, 100, 100);
}

sub set_brightness{
	my $ip = shift;
	my $brightness = shift;
	my $command = '{"smartlife.iot.smartbulb.lightingservice":{"transition_light_state":{"brightness":' . $brightness . '}}}';
	my $return = sendcmd($ip, "$command");
	my $reply = $return->{'smartlife.iot.smartbulb.lightingservice'}{'transition_light_state'}{'brightness'};
	return $reply;
}

sub get_brightness{
	my $ip = shift;
	my %reply = get_bulb_state($ip);
	my $return;
	$return = $reply{'brightness'};
	return $return;
}


# Encryption and Decryption of TP-Link Smart Home Protocol
# XOR Autokey Cipher with starting key = 171
# Based on https://www.softscheck.com/en/reverse-engineering-tp-link-hs110/
sub encrypt {
	my $key = 171;
	my @string = split(//, $_[0]);
	my $result = "\0\0\0" . chr(@string);
	foreach (@string) {
		my $a = $key ^ ord($_);
		$key = $a;
		$result .= chr($a);
	}
	return $result;
}

sub decrypt {
	my $key = 171;
	my $result = "";
	my @string = split(//, $_[0]);
	foreach (@string) {
		my $a = $key ^ ord($_);
		$key = ord($_);
		$result .= chr($a);
	}
	return $result;
}

sub sendcmd{
	my $ip = shift;
	my $command = shift;

	my $socket = new IO::Socket::INET (
		PeerHost => $ip,
		PeerPort => '9999',
		Proto => 'tcp',
	) or die "ERROR in Socket Creation : $!\n";
	IO::Socket::Timeout->enable_timeouts_on($socket);
	$socket->read_timeout(.5);
	$socket->send(encrypt($command)) or die $!;
	my $data;
	if (defined $socket) {
		$data = <$socket> or die $!;
		$socket->close();
	}


	print "Sent: $command\n" if $debug;
	my $received = substr(decrypt($data), 4);
	$received =~ s/.{1}/\{/; #always starts with a random char for some reason
	print ("Received: " . $received . "\n") if $debug;
	my $decoded = decode_json($received);
	return $decoded;
}



=pod
=begin html

<a name="TPLinkLB1x0"></a>
<h3>TPLinkLB1x0</h3>
<ul>
  <br>

  <a name="TPLinkLB1x0"></a>
  <b>Define</b>
    <code>define &lt;name&gt; TPLinkLB1x0 &lt;ip/hostname&gt;</code><br>
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

</ul>

=end html

=begin html_DE

<a name="TPLinkLB1x0"></a>
<h3>TPLinkLB1x0</h3>
<ul>
  <br>

  <a name="TPLinkLB1x0"></a>
  <b>Define</b>
    <code>define &lt;name&gt; TPLinkLB1x0 &lt;ip/hostname&gt;</code><br>
    	<br>
    Definiert eine TP-Link LB1x0 schaltbare WLAN-LED-Lampe. <br>

	Das Modul implementiert nicht alle Funktionen der LB1x0.<br>
	Derzeit werden alle für den sinnvollen Betrieb an FHEM benötigten Parameter ausgelesen.<br>
	Für eine weitergehende Programmierung der Steckdosen wird daher die TP Link App "Kasa" empfohlen, wobei deren<br>
	Funktionen wie Timer etc. letztlich redundant zu Kernfunktionen von FHEM sind.
  <p>
  <b>Attribute</b>
	<ul>
		<li><b>interval</b>: Das Intervall in Sekunden, nach dem FHEM die Messwerte aktualisiert. Default: 300s</li>
			Eine Aktualisierung der Messwerte findet auch bei jedem Schaltvorgang statt.
		<p>
		<li><b>timeout</b>:  Der Timeout in Sekunden, der bei der Kommunikation mit der Steckdose verwendet wird. Default: 1s</li>
			<i>Achtung</i>: der Timeout von 1s ist knapp gewählt. Ggf. kann es zu Fehlermeldungen kommen, wenn die Steckdose nicht 
			schnell genug antwortet.<br>
			Bitte beachten Sie aber auch, dass längere Timeouts FHEM für den Zeitraum des Requests blockieren!
		<p>
		<li><b>disable</b>: Die Ausführung des Moduls wird gestoppt. Default: no.</li>
			<i>Achtung: wenn Ihre Steckdose nicht in Betrieb oder über das WLAN erreichbar ist, sollten Sie
			dieses FHEM-Modul per Attribut "disable" abschalten, da sonst beim zyklischen Abruf der Messdaten
			der Steckdose Timeouts auftreten, die FHEM unnötig verlangsamen.</i>
	</ul>
  <p>
  <b>Requirements</b>
	<ul>
	Das Modul benötigt die folgenden Perl-Module:<br><br>
	<li> Perl Module: IO::Socket::INET </li>
	<li> Perl Module: IO::Socket::Timeout </li>
	</ul>

</ul>
=end html_DE

=item summary Support for TPLink HS100/100 wifi controlled power outlet

=item summary_DE Support für die TPLink HS100/110 WLAN Steckdosen
