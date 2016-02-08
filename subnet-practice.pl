#!/usr/bin/perl

use strict;
use warnings;

my %argument_hash;

for ( my $argc = 0; defined $ARGV[$argc]; $argc++) {
	# Detect if subnet input is CIDR or dot-decimal or whatever.
	if ( $ARGV[$argc] =~  m/^([2][5][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[1-9][0-9]|[0-9])\.
				 ([2][5][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[1-9][0-9]|[0-9])\.
				 ([2][5][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[1-9][0-9]|[0-9])\.
				 ([2][5][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[1-9][0-9]|[0-9])\/
				 ([3][0-2]|[1-2][0-9]|[0-9])$/x ) {
		# Add error handling here.
		$argument_hash{'IP_address'} = $1.".".$2.".".$3.".".$4;
		# This should be combined with the lower regex as a conditional.
		# Set the subnet quantifiers to "?" and use "if ( defined $5 )...".
		$argument_hash{'CIDR_subnet_mask'} = $5;
	} elsif ( $ARGV[$argc] =~ m/^([2][5][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[1-9][0-9]|[0-9])\.
				     ([2][5][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[1-9][0-9]|[0-9])\.
				     ([2][5][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[1-9][0-9]|[0-9])\.
				     ([2][5][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[1-9][0-9]|[0-9])$/x ) {
		if ( defined $argument_hash{'dot_decimal_subnet_mask'} ) {
			if ( defined $argument_hash{'IP_address'} ) {
				print "Only one IP address and one subnet mask may be processed.\n";
				print "Received ".$argument_hash{'IP_address'};
				print " and ".$argument_hash{'dot_decimal_subnet_mask'};
				print " and ".$1.".".$2.".".$3.".".$4."\n";
				exit 0;
			} else {
				$argument_hash{'IP_address'} = $argument_hash{'dot_decimal_subnet_mask'};
				$argument_hash{'dot_decimal_subnet_mask'} = $1.".".$2.".".$3.".".$4;
			}
		} else {
			$argument_hash{'dot_decimal_subnet_mask'} = $1.".".$2.".".$3.".".$4;
		}
	} elsif ( $ARGV[$argc] =~ m/^\/?([3][0-2]|[1-2][0-9]|[0-9])$/ ) {
		# Add error handling here. Maybe make "assign" function that checks for existing variable assignments?
		if ( defined $argument_hash{'dot_decimal_subnet_mask'} ) {
			$argument_hash{'IP_address'} = $argument_hash{'dot_decimal_subnet_mask'};
			delete $argument_hash{'dot_decimal_subnet_mask'};
		}
		$argument_hash{'CIDR_subnet_mask'} = $1;
	} else {
		# Error part of the conditional.
		# Let's try to give the user a hint of what is wrong.
		if ( $ARGV[$argc] =~ m/^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})$/ ) {
			print "Invalid IP address or subnet: ".$1."\n";
		} elsif ( $ARGV[$argc] =~ m/\/?([0-9]+)$/ ) {
			print "Invalid subnet: /".$1."\n";
		} else {
			print "Argument not recognized: ".$ARGV[$argc]."\n";
		}
		exit 1;
	}
}

# This maybe should integrated elsewhere.
if (( defined $argument_hash{'dot_decimal_subnet_mask'} ) and
    ( defined $argument_hash{'CIDR_subnet_mask'} )) {
   	print "Only one subnet mask may be requested.\n";
	print "Received ".$argument_hash{'dot_decimal_subnet_mask'}." and /".$argument_hash{'CIDR_subnet_mask'}."\n";
	exit 1;
}

if ( defined $argument_hash{'dot_decimal_subnet_mask'} ) {
	$argument_hash{'CIDR_subnet_mask'} = &convert_dot_decimal_to_CIDR_notation( $argument_hash{'dot_decimal_subnet_mask'} );
} elsif ( defined $argument_hash{'CIDR_subnet_mask'} ) {
	$argument_hash{'dot_decimal_subnet_mask'} =  &convert_CIDR_to_dot_decimal_notation( $argument_hash{'CIDR_subnet_mask'} );
}

print "Subnet mask info:\n";
print $argument_hash{'dot_decimal_subnet_mask'}."\n";
print "/".$argument_hash{'CIDR_subnet_mask'}."\n";
my $addresses_available_in_subnet = &determine_addresses_in_subnet( $argument_hash{'CIDR_subnet_mask'} );
print "Addresses available: ".$addresses_available_in_subnet."\n";
print "Hosts available : ".( $addresses_available_in_subnet - 2)."\n";
print "Binary representation: ".&convert_CIDR_to_binary_notation( $argument_hash{'CIDR_subnet_mask'} )."\n";

sub determine_addresses_in_subnet {
	# Expects two-digit CIDR subnet mask.
	my $received_CIDR_mask = shift;
	my $available_addresses_in_subnet;
	my $exponent_of_2 = ( 32 - $received_CIDR_mask );
	if ( $received_CIDR_mask <= 32 ) {
		$available_addresses_in_subnet = ( 2**$exponent_of_2 );
	} else {
		return "Invalid subnet: ".$received_CIDR_mask."\n";
	}
	return $available_addresses_in_subnet;
}

sub convert_dot_decimal_to_CIDR_notation {
	# Expects full dot-decimal subnet mask.
	my $dot_decimal_mask = shift;
	my $CIDR_mask = 0;
	my $octet = 0;
	my $previous_dot_decimal_octet;
	while ( $dot_decimal_mask =~ m/([0-9]+)/g ) {
		my $dot_decimal_octet = $1;
		my $CIDR_octet = eval( 2 + ( log( 4 - ($dot_decimal_octet / 64) ) / log (0.5) ) );
		if ( $CIDR_octet !~ m/^[0-9]+$/ ) {
			print "Invalid subnet: ".$dot_decimal_mask."\n";
			exit 1;
		} else {
			$CIDR_mask = ( $CIDR_mask + $CIDR_octet );
		}
		if ( ( defined $previous_dot_decimal_octet ) and ( $previous_dot_decimal_octet < 255 ) and ( $previous_dot_decimal_octet >= 0 ) and ( $dot_decimal_octet != 0 ) ) {
			print "Invalid subnet mask: ".$dot_decimal_mask."\n";
			exit 1;
		}
		$previous_dot_decimal_octet = $dot_decimal_octet;
	}
	return $CIDR_mask;
}

sub convert_CIDR_to_dot_decimal_notation {
	# Expects two-digit CIDR subnet mask.
	my $CIDR_mask = shift;
	my $dot_decimal_mask;
	my $octet = 0;
	my $remainder = ( $CIDR_mask % 8 );
	if ( ( $CIDR_mask < 1 ) or ( $CIDR_mask > 32 ) ) {
		print "Invalid subnet: /".$CIDR_mask."\n";
		exit 1;
	}
	for ( my $iteration = ( $CIDR_mask / 8 ); $iteration > 0; $iteration-- ) {
		$octet++;
		# Keep track of the octet we are on and correctly place decimals.
		if ( $octet > 1 ) {
			$dot_decimal_mask .= ".";
		}
		if ( $iteration < 1 ) {
			my $binary_geometric_series;
			$binary_geometric_series .= "64 ";
			$binary_geometric_series .= "* ( 2 ";
			# The "> 1" conditional is not actually mathematically necessary. The expression is still correct
			#  while "$possible_CIDR_octet" is less than or equal to 1, but perl complains about
			#  empty brackets in those situations: "( )".
			if ( $remainder > 1 ) {
				$binary_geometric_series .= "+ ( ";
				for ( my $i=0; $i < ( $remainder - 1 ); $i++ ) {
					$binary_geometric_series .= "( 0.5**$i )";
					if ( $i < ( $remainder - 2 ) ) {
						$binary_geometric_series .= "+";
					}
				}
				$binary_geometric_series .= " ) ";
			}
			$binary_geometric_series .= ")";
			$dot_decimal_mask .= eval($binary_geometric_series);
		} else {
			# We see above that $iteration = ( $CIDR_mask / 8 ).
			# If the CIDR mask is divisible by 8 at least once, then the first octet must be 255.
			# If the CIDR mask is divisible by 8 at least twice, then the first two octets must be 255; and so on.
			# We use this conditional to skip the math when it is not yet necessary.
			$dot_decimal_mask .= "255";
		}
	}
	my $empty_octets = ( 4 - $octet );
	$dot_decimal_mask .= ".0"x$empty_octets;
	return $dot_decimal_mask;
}

sub convert_CIDR_to_binary_notation {
	# Expects two-digit CIDR subnet mask.
	my $submitted_CIDR_mask = shift;
	my $number_of_binary_zeros = ( 32 - $submitted_CIDR_mask );
	my $binary_mask = "1"x$submitted_CIDR_mask;
	$binary_mask .= "0"x$number_of_binary_zeros;
	if ( $binary_mask =~ m/^([0-1]{8})([0-1]{8})([0-1]{8})([0-1]{8})$/ ) {
		$binary_mask = $1.".".$2.".".$3.".".$4;
	}
	return $binary_mask;
}

sub convert_IP_to_binary_notation {
	my $received_dot_decimal_mask = shift;
	my $binary_IP_address;
	my $binary_octet_placeholder = 0;
	while ( $received_dot_decimal_mask =~ m/([0-9]+)/g ) {
		my $numerator = $1;
		my $binary_number = '';
		my $binary_placeholder = 1;
		while ( $numerator >= 1 ) {
			my $bit = ( $numerator % 2 );
			$binary_number = $bit.$binary_number;
			$numerator = ( $numerator / 2);
			$binary_placeholder++;
		}
		my $zero_padding = ( 8 - $binary_placeholder );
		$binary_number = '0'x$zero_padding.$binary_number;
		if ( $binary_octet_placeholder > 0 ) {
			$binary_IP_address .= ".";
		}
		$binary_IP_address .= $binary_number;
		$binary_octet_placeholder++;
	}
	return $binary_IP_address;
}
