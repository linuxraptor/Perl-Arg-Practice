#!/usr/bin/perl

use strict;
use warnings;

my @ip_checking_website_array=
	( 'http://whatsmyip.net/',
	  'http://www.ipchicken.com/',
	  'http://mxtoolbox.com/WhatIsMyIP/',
	  'https://www.iplocation.net/find-ip-address',
	  'https://www.privateinternetaccess.com/pages/whats-my-ip/' );
my @specified_websites; # Turn this into an array referenced by our %argument_hash.

# I am doing command line argument processing with regex instead of GetOpt:Long because
#   there is greater flexibility for custom data structures (as used below)
#   and makes cleaner code (unlinke scalar variables, all possible hash elements do 
#   not need to be declared).
my %argument_hash;
for ( my $argument_index = 0; defined $ARGV[$argument_index]; $argument_index++ ) {
	if      ( $ARGV[$argument_index] =~ m/^\-\?$|^\-h$|^\-?\-help$/ ) {
		print "Help:\n";
		exit 0;
	} elsif ( $ARGV[$argument_index] =~ m/^\-a$|^\-?\-all$/ ) {
		$argument_hash{'check_all_websites'} = 1;
	} elsif ( $ARGV[$argument_index] =~ m/^\-q$|^\-?\-headless$/ ) {
		$argument_hash{'headless'} = 1;
	} elsif ( $ARGV[$argument_index] =~ m/^\-i$|^\-?\-interface$/ ) {
		$argument_hash{'interface_argument'} = "--interface \'".$ARGV[++$argument_index]."\'";
	} elsif ( $ARGV[$argument_index] =~ m/^\-v$|^\-?\-verbose$/ ) {
		$argument_hash{'verbose'} = 1;
	} else {
		print STDERR "Argument not recognized: ".$ARGV[$argument_index]."\n";
	}
}

if (( $argument_hash{'headless'} ) and ( $argument_hash{'verbose'} )) {
	print STDERR "Warning: Option --verbose overrides --headless.\n";
}

# Future options:
# no options - only return ip address. iterate over array until match is found. only error if all queries return no results.
# -a --all, check all websites in array. error on any query. implies --verbose.
# -v --verbose, print websites where ip address originates from. error on any query. can be combined with --target
# -s --source, accept a space-delimited list of sites (sites can have hyphens) to query.
#  if used with --all, specified sites will append to existing array. otherwise, only specified sites are used.
#  if no switches are ever specified but an argument exists, check for webite suffix and attempt to scrape an IP from it.
# -i --interface, use specified interface. if not specified, exclude --interface from curl command.
# -d --dry-run, just print the "website:" portion, do not actually curl.
# -h --headless, do not print newline after ip address. 
# -t --time, show the response time. can be used alone.
# If there is more than one site to be checked, warn if some site returns an error.
# if no IP is ever found, error upon exit.
# look for curl command in available $PATH, and error if it does not exist.
# check for curl error code, display the received error if anything but 200 is received.
# check that specified interface exists.
# functions! as always.

my $curl_command = 'curl --max-time 10 --silent';

if ( $argument_hash{'interface_argument'} ) {
	$curl_command .= " ".$argument_hash{'interface_argument'};
}

for my $ip_checking_website ( @ip_checking_website_array ) {
	if ( $argument_hash{'verbose'} ) {
		print "Website: ".$ip_checking_website."\n";
	}
	my $curl_response=qx($curl_command \"$ip_checking_website\" 2>&1);
	# Specifically search for acceptable IP addresses: 0.0.0.0 - 255.255.255.255
	# 			   255-250 or   249-200  or  199-100   or  99-10 or 9-0
	if ( $curl_response =~ m/([25][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[1-9][0-9]|[0-9])\.
				 ([25][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[1-9][0-9]|[0-9])\.
				 ([25][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[1-9][0-9]|[0-9])\.
				 ([25][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[1-9][0-9]|[0-9])/x ) {
		print $1.".".$2.".".$3.".".$4;
		if ( ! $argument_hash{'headless'} ) {
			print "\n";
		}
		if (( $argument_hash{'check_all_websites'} ) or ( @specified_websites > 1 )) {
			next;
		} else {
			last;
		}
        } else {
                print STDERR "No match found.\n";
        }
}

