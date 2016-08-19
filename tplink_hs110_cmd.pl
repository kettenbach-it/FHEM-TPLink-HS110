#!/usr/bin/perl

# Command Line Tool for TP-Link HS-100/110 wifi controlled power outlets
# Copyright: Volker Kettenbach, 2016
# volker@kettenbach-it.de

use strict;
use warnings;
use IO::Socket::INET;
use JSON;
use Getopt::Simple;


my %commands = (	'info' 		=> '{"system":{"get_sysinfo":{}}}',
                        'on'		=> '{"system":{"set_relay_state":{"state":1}}}',
                        'off'		=> '{"system":{"set_relay_state":{"state":0}}}',
                        'cloudinfo'	=> '{"cnCloud":{"get_info":{}}}',
                        'wlanscan'	=> '{"netif":{"get_scaninfo":{"refresh":0}}}',
                        'time'		=> '{"time":{"get_time":{}}}',
                        'schedule'	=> '{"schedule":{"get_rules":{}}}',
                        'countdown'	=> '{"count_down":{"get_rules":{}}}',
                        'antitheft'	=> '{"anti_theft":{"get_rules":{}}}',
                        'reboot'	=> '{"system":{"reboot":{"delay":1}}}'
);
my $remote_port = 9999;
my $clist;
foreach(sort keys %commands) {
	$clist .= $_ .", ";
}

my ($options) = {	help	=>	{
				type    => '',
				default => '',
				order   => 1,
				verbose	=> 'Print this help text'
			},
			ip	=>	{
				type 	=> '=s',
				verbose => 'Specifiy the hostname/ip of the TPLink HS100/110'
			},
			command =>	{
				type 	=> '=s',
				verbose => 'Specify the command to send to the TPLink HS100/110 out of: '.$clist
			},
			verbose =>	{
				verbose	=> 'Be verbose'
			},
};


my($option) = Getopt::Simple -> new();
if (!$option -> getOptions($options, "Usage: $0 [options]") ) {
	exit(-1);       # Failure.
}

my $isVerbose=0;
if ($$option{'switch'}{'verbose'}) {
	$isVerbose=1;
}

my $command;
if (!$$option{'switch'}{'command'}) {
	$option->helpOptions();
	print "No command given!";
	exit (-1);
} else {
	if (!exists($commands{$$option{'switch'}{'command'}})){
		print "Invalid command! ";
		print "Please give a command out of: $clist";
		exit (-1);
	} else {
		if ($isVerbose){
			print "Sending command: <".$$option{'switch'}{'command'}.">";
		}
	}
	$command = $$option{'switch'}{'command'};
}

my $jcommand = $commands{$$option{'switch'}{'command'}};
my $remote_host;
if (!$$option{'switch'}{'ip'}) {
	$option->helpOptions();
	print "No ip given!";
	exit (-1);
} else {
	if ($isVerbose){
		#print " to " . $$option{'switch'}{'ip'}.". ($jcommand) \n";
		print " to " . $$option{'switch'}{'ip'}.". \n";
	}
	$remote_host = $$option{'switch'}{'ip'};
}

# Encryption and Decryption of TP-Link Smart Home Protocol
# XOR Autokey Cipher with starting key = 171
# Based on https://www.softscheck.com/en/reverse-engineering-tp-link-hs110/
sub encrypt {
	my $key = 171;
	my $result = "\0\0\0\0";
	my @string=split(//, $_[0]);
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
	Type     => SOCK_STREAM ) 
	or die "Couldn't connect to $remote_host:$remote_port: $@\n";
$socket->send($c);
my $data;
$socket->recv($data,64);
$socket->close();
$data = decrypt(substr($data,4));
my $json = decode_json($data);
#print "Received answer: " . $data . "\n" if $isVerbose;

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
if ($command eq "antitheft"){
	print "Results: \n";
	foreach my $key (sort keys %{$json->{'anti_theft'}->{'get_rules'}}) {
		#if ($key eq "rule_list") {
		#	foreach my $key2 (sort keys %{$json->{'anti_theft'}->{'get_rules'}->{'rule_list'}}) {
		#		print " " . $key2 . ": " . $json->{'anti_theft'}->{'get_rules'}->{'rule_list'}->{$key2} . "\n";
		#	}
		#} else {
			print " " . $key . ": " . $json->{'anti_theft'}->{'get_rules'}->{$key} . "\n";
			#}
	}
}
if ($command eq "countdown"){
	print "Results: \n";
	foreach my $key (sort keys @{$json->{'count_down'}->{'get_rules'}->{'rule_list'}}) {
		print " " . $key . ": " . $json->{'count_down'}->{'get_rules'}->{'rule_list'}->{$key} . "\n";
	}
}
if ($command eq "schedule"){
	print "Results: \n";
	foreach my $key (sort keys %{$json->{'schedule'}->{'get_rules'}}) {
		print " " . $key . ": " . $json->{'schedule'}->{'get_rules'}->{$key} . "\n";
	}
}

