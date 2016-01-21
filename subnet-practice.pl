#!/usr/bin/perl

use strict;
use warnings;

#print &convert_dot_decimal_to_CIDR_notation(192)."\n";

#print &convert_CIDR_to_binary_notation(24)."\n";
print &convert_CIDR_to_dot_decimal_notation($ARGV[0])."\n";

sub convert_dot_decimal_to_CIDR_notation {
	# start testing with a single octet, then work up to a full set.
	my $dot_decimal_mask = shift;
	# Our binary is base 2 with a single "1" bit to allow for odd numbers. Add this "1" bit to our base 2 so the logs will work.
	$dot_decimal_mask += 1;
	my $CIDR_mask = log($dot_decimal_mask) / log(2);
	return $CIDR_mask;
}

sub convert_CIDR_to_dot_decimal_notation {
	my $CIDR_mask = shift;
	my $dot_decimal_mask;
	my $octet = 0;
	my $remainder = ( $CIDR_mask % 8 );
	for ( my $iteration = ( $CIDR_mask / 8 ); $iteration > 0; $iteration-- ) {
		$octet++;	
		if ( $octet > 1 ) {
			$dot_decimal_mask .= ".";
		}
		if ( $iteration >= 1 ) {
			$dot_decimal_mask .= "255";
		} else {
			# I am going to simplify as little as possible so it is easier to see where the math came from.
			my $binary_geometric_series;
			$binary_geometric_series .= "8 * 8 ";
			$binary_geometric_series .= "* ( 2 ";
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
		}
	}
	my $zero_octets = ( 4 - $octet );
	$dot_decimal_mask .= ".0"x$zero_octets;
	
	return $dot_decimal_mask;
}

sub convert_CIDR_to_binary_notation {
	my $submitted_CIDR_mask = shift;
	my $number_of_binary_zeros = ( 32 - $submitted_CIDR_mask );
	my $binary_mask = "1"x$submitted_CIDR_mask;
	$binary_mask .= "0"x$number_of_binary_zeros;
	if ( $binary_mask =~ m/^([0-1]{8})([0-1]{8})([0-1]{8})([0-1]{8})$/ ) {
		$binary_mask = $1.".".$2.".".$3.".".$4;
	}
	return $binary_mask;
}

sub convert_dot_decimal_to_binary_notation {
	my $submitted_dot_decimal_mask = shift;
	my $returned_CIDR_mask = &convert_dot_decimal_to_CIDR_notation($submitted_dot_decimal_mask);
	my $returned_binary_mask = &convert_CIDR_to_binary_notation($returned_CIDR_mask);
	return $returned_binary_mask;
}
