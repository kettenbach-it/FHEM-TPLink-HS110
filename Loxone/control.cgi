#!/usr/bin/perl

# Web tool for TP-Link HS-100/110 wifi controlled power outlets
# Christian Fenzl 2017 for LoxBerry
# Based on https://github.com/kettenbach-it/FHEM-TPLink-HS110 from Volker Kettenbach, 2016
#

use strict;
use warnings;
use CGI;
use IO::Socket::INET;
use IO::Socket::Timeout;
use JSON;
use Data::Dumper;

my $timeout=3;

my $cgi= CGI->new;
$cgi->import_names('R');
print $cgi->header('text/plain');

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$mon++;
$year += 1900;


my %commands = (	'info' 		=> '{"system":{"get_sysinfo":{}}}',
                        'on'		=> '{"system":{"set_relay_state":{"state":1}}}',
                        'off'		=> '{"system":{"set_relay_state":{"state":0}}}',
                        'cloudinfo'	=> '{"cnCloud":{"get_info":{}}}',
                        'wlanscan'	=> '{"netif":{"get_scaninfo":{"refresh":0}}}',
                        'wlanscanfresh'	=> '{"netif":{"get_scaninfo":{"refresh":1}}}',
                        'json' => '', #to be set later
                        'time'		=> '{"time":{"get_time":{}}}',
                        'schedule'	=> '{"schedule":{"get_rules":{}}}',
                        'countdown'	=> '{"count_down":{"get_rules":{}}}',
                        'antitheft'	=> '{"anti_theft":{"get_rules":{}}}',
			'nightmodeon'	=> '{"system":{"set_led_off":{"off":1}}}',
			'nightmodeoff'	=> '{"system":{"set_led_off":{"off":0}}}',
			'realtime'	=> '{"emeter":{"get_realtime":{}}}',
			'monthstat'	=> '{"emeter":{"get_monthstat":{"year":'.$year.'}}}',
			'daystat'	=> '{"emeter":{"get_daystat":{"month":'.$mon.',"year":'.$year.'}}}',
                        'reboot'	=> '{"system":{"reboot":{"delay":1}}}'
);
my $remote_port = 9999;
my $clist;
foreach(sort keys %commands) {
	$clist .= $_ .", ";
}

# my ($options) = {	help	=>	{
				# type    => '',
				# default => '',
				# order   => 1,
				# verbose	=> 'Print this help text'
			# },
			# ip	=>	{
				# type 	=> '=s',
				# verbose => 'Specifiy the hostname/ip of the TPLink HS100/110'
			# },
			# command =>	{
				# type 	=> '=s',
				# verbose => 'Specify the command to send to the TPLink HS100/110 out of: '.$clist
			# },
			# verbose =>	{
				# verbose	=> 'Be verbose'
			# },
            # json => {
                # type    => '=s',
                # verbose => 'arbitrary json string to send to the TPLink HS100/110 (check tplink-smarthome-commands.txt)'
            # }
# };


# my($option) = Getopt::Simple -> new();
# if (!$option -> getOptions($options, "Usage: $0 [options]") ) {
	# exit(-1);       # Failure.
# }

my $isVerbose=0;
if ($R::verbose)  {
	$isVerbose=1;
}

my $command;
my $jcommand = $commands{$R::command};
print "jcommand: $jcommand\n";
if (!$jcommand) {
	print "No command given!";
	exit (1);
} else {
	if (!exists($commands{$R::command})){
		print "Invalid command! Please give a command out of: $clist";
		exit (1);
	} else {
		if ($isVerbose){
			print "Sending command: <" . $jcommand . "> = $jcommand";
		}
	}
	$command = $commands{$R::command};
}

my $remote_host;
if (!$R::ip) {
	print "No ip given!";
	exit (1);
} else {
	if ($isVerbose){
		print " to " . $R::ip .". \n";
	}
	$remote_host = $R::ip;
}

# if($command eq 'json') {
    # $jcommand = $$option{'switch'}{'json'};
# }

# Encryption and Decryption of TP-Link Smart Home Protocol
# XOR Autokey Cipher with starting key = 171
# Based on https://www.softscheck.com/en/reverse-engineering-tp-link-hs110/
sub encrypt {
        my $key = 171;
		my @string=split(//, $_[0]);
        my $result = "\0\0\0".chr(@string);
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
        my @string=split(//, $_[0]);
        foreach (@string) {
                my $a = $key ^ ord($_);
                $key = ord($_);
                $result .= chr($a);
        }
        return $result;
}


my $c = encrypt($jcommand);
my $socket = IO::Socket::INET->new(PeerAddr => $remote_host,
	PeerPort => $remote_port,
	Proto    => 'tcp',
	Type     => SOCK_STREAM,
	Timeout  => $timeout) 
	or die "Couldn't connect to $remote_host:$remote_port: $@\n";
$socket->send($c);
my $data;
$socket->read($data,8192);
$socket->close();
$data = decrypt(substr($data,4));
print "Received answer: " . $data. "\n" if $isVerbose;
my $json = decode_json($data);

if ($command eq "on" || $command eq "off") {
	if ($json->{'system'}->{'set_relay_state'}->{'err_code'} eq "0") {
		print "Command successfull" if $isVerbose;	
		exit (0);
	} else{
		print "Command failed";
		exit(1);
	}
}
if ($command eq "reboot"){
	if ($json->{'system'}->{'reboot'}->{'err_code'} eq "0") {
		print "Command successfull" if $isVerbose;	
		exit (0);
	} else{
		print "Command failed";
		exit(1);
	}
}

if ($command eq "time") {
	print "The time on $remote_host is: ";
	print $json->{'time'}->{'get_time'}->{'year'}."-";
	print $json->{'time'}->{'get_time'}->{'month'}."-";
	print $json->{'time'}->{'get_time'}->{'mday'}. " ";
	print $json->{'time'}->{'get_time'}->{'hour'}.":";
	print $json->{'time'}->{'get_time'}->{'min'}.":";
	print $json->{'time'}->{'get_time'}->{'sec'};
}
if ($command eq "info"){
	print "Results: \n";
	foreach my $key (sort keys %{$json->{'system'}->{'get_sysinfo'}}) {
		print " " . $key . ": " . $json->{'system'}->{'get_sysinfo'}->{$key} . "\n";
	}
}
if ($command eq "cloudinfo"){
	print "Results: \n";
	foreach my $key (sort keys %{$json->{'cnCloud'}->{'get_info'}}) {
		print " " . $key . ": " . $json->{'cnCloud'}->{'get_info'}->{$key} . "\n";
	}
}
if ($command eq "realtime"){
	print "Results: \n";
	foreach my $key (sort keys %{$json->{'emeter'}->{'get_realtime'}}) {
		print " " . $key . ": " . $json->{'emeter'}->{'get_realtime'}->{$key} . "\n";
	}
}
if ($command eq "monthstat"){
	print "Results: \n";
	foreach my $key (sort keys @{$json->{'emeter'}->{'get_monthstat'}->{'month_list'}}) {
		foreach my $key2 ($json->{'emeter'}->{'get_monthstat'}->{'month_list'}[$key]) {
			print $key2->{'year'}."-".$key2->{'month'}.": " . $key2->{'energy'}."\n";
		}
	}
}
if ($command eq "daystat"){
	my $total=0;
	print "Results: \n";
	foreach my $key (sort keys @{$json->{'emeter'}->{'get_daystat'}->{'day_list'}}) {
		foreach my $key2 ($json->{'emeter'}->{'get_daystat'}->{'day_list'}[$key]) {
			print $key2->{'year'}."-".$key2->{'month'}."-".$key2->{'day'}.": " . $key2->{'energy'}."\n";
			$total = $total+ $key2->{'energy'};
		}
	}
	my $count = @{$json->{'emeter'}->{'get_daystat'}->{'day_list'}};
	print "Monthly total: $total\n";
	print "Daily average: " . $total / $count;
}
if ($command eq "antitheft"){
	if (scalar (@{$json->{'anti_theft'}->{'get_rules'}->{'rule_list'}}) eq 0) {
		print "No awaymode set";
	} else {
		print "Aaway Mode: \n";
		foreach my $key (sort keys @{$json->{'anti_theft'}->{'get_rules'}->{'rule_list'}}) {
			foreach my $key2 ($json->{'anti_theft'}->{'get_rules'}->{'rule_list'}[$key]) {
				print "Enabled: " if ($key2->{'enable'} eq 1);
				print "Disabled: " if ($key2->{'enable'} eq 0);
				print Dumper $key2;
			}
		}
	}
}
if ($command eq "countdown"){
	if (scalar (@{$json->{'count_down'}->{'get_rules'}->{'rule_list'}}) eq 0) {
		print "No timer set";
	} else {
		print "Timer: \n";
		foreach my $key (sort keys @{$json->{'count_down'}->{'get_rules'}->{'rule_list'}}) {
			foreach my $key2 ($json->{'count_down'}->{'get_rules'}->{'rule_list'}[$key]) {
				print "Timer enabled: " if ($key2->{'enable'} eq 1);
				print "Timer disabled: " if ($key2->{'enable'} eq 0);
				print $key2->{'name'} . " ";
				print "Delay: " . $key2->{'delay'}."s, ";
				print "Activity: ";
				print "On" if ($key2->{'act'} eq 1);
				print "Off" if ($key2->{'act'} eq 0);
			}
		}
	}
}
if ($command eq "schedule"){
	if (scalar (@{$json->{'schedule'}->{'get_rules'}->{'rule_list'}}) eq 0) {
		print "No schedules";
	} else {
		print "Schedules:\n";
		foreach my $key (sort keys @{$json->{'schedule'}->{'get_rules'}->{'rule_list'}}) {
			foreach my $key2 ($json->{'schedule'}->{'get_rules'}->{'rule_list'}[$key]) {
				print "Enabled rule: " if ($key2->{'enable'} eq 1);
				print "Disabled rule: " if ($key2->{'enable'} eq 0);
				print $key2->{'name'} . " ";
				print Dumper $key2;
			}
		}
	}
}
if ($command eq "wlanscan" | $command eq "wlanscanfresh"){
	if (scalar (@{$json->{'netif'}->{'get_scaninfo'}->{'ap_list'}}) eq 0) {
		print "No networks. Try command <wlanscanfresh>";
	} else {
		print "Networks:\n";
		foreach my $key (sort keys @{$json->{'netif'}->{'get_scaninfo'}->{'ap_list'}}) {
			foreach my $key2 ($json->{'netif'}->{'get_scaninfo'}->{'ap_list'}[$key]) {
				print "\t";
				print "Open" if ($key2->{'key_type'} eq 0);
				print "WEP" if ($key2->{'key_type'} eq 1);
				print "WPA" if ($key2->{'key_type'} eq 2);
				print "WPA2" if ($key2->{'key_type'} eq 3);
				print "\t";
				print $key2->{'ssid'} . "\n";
			}
		}
	}
}
