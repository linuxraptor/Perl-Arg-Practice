#!/usr/bin/perl

use warnings;
use strict;

# curl 'http://www.ipaddresslocation.org/ip_ranges/get_ranges.php' -H 'Origin: http://www.ipaddresslocation.org' -H 'Accept-Encoding: gzip, deflate' -H 'Accept-Language: en-US,en;q=0.8' -H 'Upgrade-Insecure-Requests: 1' -H 'Content-Type: application/x-www-form-urlencoded' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8' -H 'Cache-Control: max-age=0' -H 'Referer: http://www.ipaddresslocation.org/ip_ranges/get_ranges.php' -H 'Connection: keep-alive' --data 'country=US&prefix=&output=ipranges' --compressed --output united-states-subnets.txt --silent

# the above file likes to think it is gzipped, but it is not. plaintext is returned.
# the source above gives a complete list of ip address ranges. other sites only gave ranges above a certain size (usually 16,384)
# the question remains: do i want ip address information from a third party? or should i get it from the source? (IANA/ARIN)

# Organizations:
# ICANN - Internet Corporation for Assigned Names and Numbers
# IANA - Internet Assigned Numbers Authority
# ARIN - American Registry for Internet Numbers
# APNIC - Asia Pacific Network Information Centre
# The function of these organizations can be found here:
# https://www.icann.org/resources/pages/welcome-2012-02-25-en
# " What Does ICANN Do?
#   ICANN coordinates the Internet Assigned Numbers Authority (IANA) functions. "
#
# All of these organizations are not for profit.
# ICANN seems to be the global governing body of internet address space, protocols, regulations, and standards.
# ICANN is contracted by the U.S. Government.
# ICANN employs the IANA to help with the internet address portion of their responsibilities.
# The IANA evaluates and assigns IP address space as requested by regional IP address registries.
# The North American registry is "ARIN", the Asia-Pacific registry is "APNIC". These are the largest.
# There are currently only three smaller registries: AfriNIC, RIPE, and LACNIC.
# Each internet-connected country on our planet has their address space governed by one of these registries.
# A complete list of countries and their associated registries can be found on the APNIC website:
# https://www.apnic.net/services/apply-for-resources/iso-3166-codes
#
# Due to the IANA's global nature, they maintain an index of allocated IP address space on their website:
# http://www.iana.org/assignments/ipv4-address-space/ipv4-address-space.xml
# This index is the global standard, it is very complete.  The most useful information here is that
# not only is each IP address allocation's organization listed, but their associated registry is 
# noted as well.  At very least, this should allow IP addresses to be regionally (or continentally) located.

# Work to do:
# I need to compare results gathered from ipaddresslocation.org against the subnet prefixes in the IANA document.
# I do not know if all the smaller subnets are accounted for.  I am not sure how they could be, seeing as they're
# sometimes only a dozen IP addresses in size and all the IANA prefixes are /8 (~16.8M addresses).

# should also account for private ip address space:
# https://www.arin.net/simplewebutils/whatsmyip.html
# 10.0.0.0/8 IP addresses: 10.0.0.0 -- 10.255.255.255
# 172.16.0.0/12 IP addresses: 172.16.0.0 -- 172.31.255.255
# 192.168.0.0/16 IP addresses: 192.168.0.0 – 192.168.255.255

# I am no longer sure what the scope of this project is.
# Perhaps it will be to provide rough geolocation services for requested addresses.

# my %subnet_hash
# build subnets hash data structure
# for row in subnet_file
#  if $row =~ m/^WHATEVER$/
#   $subnet_hash{$1} = $2;
#  }

# going to need a subnet hash data structure.
# beginning IP : end IP

# my %user_ip_address_hash;
# get ip from user
# if $ip =~ m/^([0-9]){1,3}\.([0-9]){1,3}\.([0-9]){1,3}\.([0-9]){1,3}$/
#  $user_ip_address_hash{'first_octet'} = $1
#  $user_ip_address_hash{'second_octet'} = $2
#  $user_ip_address_hash{'third_octet'} = $3
#  $user_ip_address_hash{'fourth_octet'} = $4

#  for my subnet in ( keys subnet_hash )

#  my %first_subnet_ip,%last_subnet_ip
#  if $subnet =~ m/^([0-9]){1,3}\.([0-9]){1,3}\.([0-9]){1,3}\.([0-9]){1,3}$/
#   $first_subnet_ip{'first_octet'} = $1
#   $first_subnet_ip{'second_octet'} = $2
#   $first_subnet_ip{'third_octet'} = $3
#   $first_subnet_ip{'fourth_octet'} = $4
#  if $subnet_hash{$subnet} =~ m/^([0-9]){1,3}\.([0-9]){1,3}\.([0-9]){1,3}\.([0-9]){1,3}$/
#   $last_subnet_ip{'first_octet'} = $1
#   $last_subnet_ip{'second_octet'} = $2
#   $last_subnet_ip{'third_octet'} = $3
#   $last_subnet_ip{'fourth_octet'} = $4
#
#  if first octet in subnet is the same as ip
#    if second octet in subnet is less than or equal to ip AND second octet in subnet ending ip is greater than or equal to ip
#      if third octet in subnet is less than or equal to ip AND third octet in subnet ending ip is greater than or equal to ip
#        if fourth octet in subnet is less than or equal to ip AND fourth octet in subnet ending ip is greater than or equal to ip
#          verbose: match found, in range: (hash elements)
#          headless: 1
#          last;
#        else: next
#      else: next
#    else: next
#  else: next
