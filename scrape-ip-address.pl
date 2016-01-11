#!/usr/bin/perl

use strict;
use warnings;

my $interface="tun0";
my @ip_checking_website_array=
	( 'http://whatsmyip.net/',
	  'http://www.ipchicken.com/',
	  'http://mxtoolbox.com/WhatIsMyIP/',
	  'https://www.iplocation.net/find-ip-address',
	  'https://www.privateinternetaccess.com/pages/whats-my-ip/' );
my $check_all_websites;
my @specified_websites;
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
# functions! as always.

for my $ip_checking_website ( @ip_checking_website_array ) {
	# Make this an option.
	# print "Website: ".$ip_checking_website."\n";;
	my $curl_response=qx(curl --interface \"$interface\" --max-time 10 --silent \"$ip_checking_website\" 2>&1);
	# Specifically search for acceptable IP addresses: 0.0.0.0 - 255.255.255.255
	# 			   255-250 or   249-200  or  199-100   or  99-10 or 9-0
	if ( $curl_response =~ m/([25][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[1-9][0-9]|[0-9])\.
				 ([25][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[1-9][0-9]|[0-9])\.
				 ([25][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[1-9][0-9]|[0-9])\.
				 ([25][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[1-9][0-9]|[0-9])/x ) {
		print $1.".".$2.".".$3.".".$4."\n";
		if (( $check_all_websites ) or ( @specified_websites > 1 )) { 
			next;
		} else {
			last;
		}
        } else {
                print STDERR "No match found.\n";
        }
}

