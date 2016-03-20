#!/usr/bin/perl

use warnings;
use strict;
use Data::Dumper;

# This is specifically the radix algo for sorting the least significant digit.

my @unsorted_numbers;
my %argument_hash;

for ( my $argc = 0; defined $ARGV[$argc]; $argc++ ) {
	if ( $ARGV[$argc] =~ m/^\-?\-help$|^\-h$|^\-?$/ ) {
		&help();
	} elsif ( $ARGV[$argc] =~ m/^\-?\-delimiter$|^\-d$/ ) {
		# Add support for NUL ?
		$argument_hash{'delimiter'} = $ARGV[++$argc];
	} elsif ( $ARGV[$argc] =~ m/^\-?\-verbose$|^-v$/ ) {
		 $argument_hash{'verbose'} = 1;
	} else {
		push @unsorted_numbers , $ARGV[$argc];
	}
}

# Find the number of digits in the largest number.
my $largest_num_of_digits = 0;
for my $unsorted_number ( @unsorted_numbers ) {
	if ( length $unsorted_number > $largest_num_of_digits ) {
		$largest_num_of_digits = ( length $unsorted_number );
	}
}

# Pad each number so that every number has the same number of digits.
my @padded_unsorted_numbers;
for my $unsorted_number ( @unsorted_numbers ) {
	my $padded_unsorted_number = "0" x ( $largest_num_of_digits - length $unsorted_number ) . $unsorted_number;
	push @padded_unsorted_numbers , $padded_unsorted_number;
}
undef @unsorted_numbers;

# Create 10 buckets, one for each digit 0-9.
my @container_of_buckets;
for my $least_significant_digit ( 0 .. 9 ) {
	@container_of_buckets[$least_significant_digit] = [];
}

# Place each unsorted number into buckets by their least-significant digit.
if ( defined $argument_hash{'verbose'} ) {
	print $largest_num_of_digits." iterations expected.\n\n";
}

# Start rearranging numbers until we get it correct.
for ( my $iteration = 1; $iteration <= $largest_num_of_digits; $iteration++ ) {
	if ( defined $argument_hash{'verbose'} ) {
		print "Iteration ".$iteration.":\n";
	}
	for my $padded_unsorted_number ( @padded_unsorted_numbers ) {
		my $least_significant_digit =  ( substr $padded_unsorted_number, ( 0 - $iteration), ( $iteration - ( $iteration - 1 ) ) );
		if ( defined $argument_hash{'verbose'} ) {
			print "Current significant digit of ".$padded_unsorted_number." is ".$least_significant_digit."\n";
		}
		push @{$container_of_buckets[$least_significant_digit]}, $padded_unsorted_number;
	}
	@padded_unsorted_numbers = ();
	for my $least_significant_digit ( 0 .. 9 ) {
		if ( defined $argument_hash{'verbose'} ) {
			print "Bucket ".$least_significant_digit." : ";
		}
		foreach ( my $i = 0; $i < ( scalar @{$container_of_buckets[$least_significant_digit]} ); $i++ ) {
			my $padded_unsorted_number = $container_of_buckets[$least_significant_digit][$i];
			if ( defined $argument_hash{'verbose'} ) {
				print $padded_unsorted_number." ";
			}
			push @padded_unsorted_numbers, $padded_unsorted_number;
		}
		@container_of_buckets[$least_significant_digit] = [];
		if ( defined $argument_hash{'verbose'} ) {
			print "\n";
		}
	}
	if ( defined $argument_hash{'verbose'} ) {
		if ( $iteration == $largest_num_of_digits ) {
			print "Final ordered list: ";
		} else {
			print "Unordered list in progress: ";
		}
		for ( my $i = 0; $i < ( scalar @padded_unsorted_numbers ); $i++ ) {
			print $padded_unsorted_numbers[$i]." ";
		}
		print "\n\n";
	}
}

for ( my $i = 0; $i < ( scalar @padded_unsorted_numbers ); $i++ ) {
	if ( $padded_unsorted_numbers[$i] =~ m/^[0]*([0-9]+)$/ ) {
		print $1." ";
	}
}
print "\n";


sub help {
	my $help_string = '';
	$help_string .= "             radix-sort-practice.pl\n";
	$help_string .= "The purpose of this script is to make a working example\n";
	$help_string .= "of the \"radix\" sorting algorithm. This script sorts\n";
	$help_string .= "based on the least significant digit of the inputted\n";
	$help_string .= "numbers.\n";
	$help_string .= "\n";
	$help_string .= "USAGE:   radix-sort-practice.pl [OPTIONS] [NUMBERS]\n";
	$help_string .= "         radix-sort-practice.pl --delimiter ':' 57 26 96 18\n";
	$help_string .= "\n";
	$help_string .= "OPTIONS:\n";
	$help_string .= " --help, -h       Print this help screen. Ignores all other options.\n";
	$help_string .= " --delimiter, -d  Set the delimiter for outputted sorted numbers.\n";
	print $help_string;
	exit 0;
}
