#!/usr/bin/perl

use strict;
use warnings;
use FileHandle;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use Data::Dumper;

my %argument_hash;
my @unreadable_files;

# Process command line arguments in one big loop.
for ( my $argc = 0; defined $ARGV[$argc]; $argc++ ) {
	if ( $ARGV[$argc] =~ m/^\-?\-help$|^-h$|^-\?$/ ) {
		&help();
	} elsif ( $ARGV[$argc] =~ m/^\-\-count-ip$/ ) {
		$argument_hash{'count-ip'} = 1;
	} elsif ( $ARGV[$argc] =~ m/^\-?\-jobs$|^-j$/ ) {
		 $argument_hash{'jobs'} = $ARGV[++$argc];
	} elsif ( $ARGV[$argc] =~ m/^\-?\-head$|^-h$/ ) {
		$argument_hash{'top_results'} = $ARGV[++$argc];
	} elsif ( $ARGV[$argc] =~ m/^\-?\-pretty$|^-p$/ ) {
		$argument_hash{'pretty'} = 1;
	} else {
		$argument_hash{'target'} = $ARGV[$argc];
	}
}

# I do not want this script to strictly depend on the parallel fork manager.
# This prevents it from becoming a permanent dependency and only requests it if needed.
if ( defined $argument_hash{'jobs'} ) {
	my $parallel_forkmanager_module = 'Parallel::ForkManager';
	eval "use $parallel_forkmanager_module";
	# Check the eval-created STDERR array for errors. If there are errors, die.
	if ( defined $@ and length $@ ) {
		print STDERR "Cannot load perl module, make sure it is installed: ".$parallel_forkmanager_module."\n";
		print STDERR $@;
		# 2 seems to be the standard "cannot load module" error code.
		exit 2;
	}
}

# Sort out the objects to process.
my @files_to_process;
if ( defined $argument_hash{'target'} 
and &target_exists( $argument_hash{'target'} ) 
and &target_is_readable( $argument_hash{'target'} ) ) {
	if ( &target_is_directory( $argument_hash{'target'} ) ) {
		print "Directory detected: ".$argument_hash{'target'}."\n";
		@files_to_process = &get_dir_contents( $argument_hash{'target'} );
	} else { 
		push @files_to_process, $argument_hash{'target'};
	}
} else {
	# This should not be necessary since we catch this in the submodules, but exists just for testing.
	print STDERR "Target does not exist or is not readable.\n";
	exit 1;
}

# Output should be something like
# Pull all available files into an array
# For files that cannot be read or are not logfiles, put in a warning array
# If no readable logfiles are available, die with an unhappy exit code
# Otherwise
# Dump warning array last, even after results.

# BASH nasty one-liner that inspired it all:
# tail -n 300 error_log | perl -ne 'if ( $_ =~ m/\[client ([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\]/ ) { print $1."\n"; } else { print "No match found.\n"; }' | sort | uniq -c | sort -rn


if ( defined $argument_hash{'count-ip'} ) {
	my %ip_hash;
	my $process_fork_manager;
	# Only activate the parallel fork manager if it is requested and available.
	if ( defined $argument_hash{'jobs'} ) {
		# Let's mix procedural and object-oriented programming, woo! </ sarcasm >
		$process_fork_manager = Parallel::ForkManager->new( $argument_hash{'jobs'} );
	}
	# This is a loop label for Parallel::ForkManager.
	LOGFILE_PROCESSING_LOOP:
	for my $file ( @files_to_process ) {
		# To allow the parallel system to work, each child process needs its own hash.
		my %child_ip_hash;
		if ( defined $argument_hash{'jobs'} ) {
			$process_fork_manager->run_on_finish(
				sub {
					my ($child_pid, $exit_code, $ident, $exit_signal, $core_dump, $temp_ip_hash_reference) = @_;
					if ( defined $temp_ip_hash_reference ) {
						for my $key ( keys %{$temp_ip_hash_reference} ) {
							if ( defined $ip_hash{$key} ) {
								$ip_hash{$key} += ${$temp_ip_hash_reference}{$key};
							} else {
								$ip_hash{$key} = ${$temp_ip_hash_reference}{$key};
							}
						}
					}
				}
			); # Yep, all wrapped in an argument. Weird, right?
			$process_fork_manager->start and next LOGFILE_PROCESSING_LOOP;
		}
		print "Analyzing: ".$file."\n";
		my $filehandle;
		if ( $file =~ m/gz$/ ) {
			# Pretty much straight from the module's manual.
			$filehandle = new IO::Uncompress::Gunzip $file
				or die "gunzip failed: $GunzipError\n"; # Find a way to put "next" with the error.
		} else {
			open $filehandle, '<', $file or push @unreadable_files, $file;
		}
		for my $line (<$filehandle>) {
			# This could be more strict ( only catch octets 0-255),
			# but how much improvement will that provide for the additional computational cost? Regex is expensive.
			if ( $line =~ m/([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})/ ) {
				if ( defined $argument_hash{'jobs'} ) {
					if ( defined $child_ip_hash{$1} ) {
						$child_ip_hash{$1}++;
					} else {
						$child_ip_hash{$1} = 1;
					}
				} else {
					if ( defined $ip_hash{$1} ) {
						$ip_hash{$1}++;
					} else {
						$ip_hash{$1} = 1;
					}
				}
			}	
		}
		close $filehandle;
		if ( defined $argument_hash{'jobs'} ) {
			$process_fork_manager->finish( 0, \%child_ip_hash );
		}
	}
	if ( defined $argument_hash{'jobs'} ) {
		$process_fork_manager->wait_all_children;
	}
	if ( not defined $argument_hash{'top_results'} ) {
		$argument_hash{'top_results'} = 10;
	}
	my $first_numeric_result = 1;
	my $numeric_buffer;
	for my $ip_address ( sort { $ip_hash{$b} <=> $ip_hash{$a} or $b cmp $a } keys %ip_hash ) {
		if ( $argument_hash{'top_results'} > 0 ) {
			if ( defined $argument_hash{'pretty'} ) {
				if ( $first_numeric_result == 1 ) {
					$numeric_buffer = ( ( length $ip_hash{$ip_address} ) + 1 );
				}
				print " " x ( $numeric_buffer - length $ip_hash{$ip_address} );
			}
			print $ip_hash{$ip_address}." ".$ip_address."\n";
			$argument_hash{'top_results'}--;
		} else {
			last;
		}
		$first_numeric_result = 0;
	}
}

sub help {
	print "Usage: apache-log-scanner.pl [-h|logfile|directory|filesearch]\n";
	exit 0;
}

sub target_is_readable {
	my $target = shift;
	if ( -r $target ) {
		return 1;
	} else {
		print STDERR "Error: File or directory cannot be read (permissions?): ".$target."\n";
		exit 1;
	}
}

sub target_exists {
	my $target = shift;
	if ( -e $target ) {
		return 1;
	} else {
		print STDERR "Error: File or directory does not exist: ".$target."\n";
		exit 1;
	}
}

sub target_is_directory {
	my $target = shift;
	if ( -d $target ) {
		return 1;
	} else {
		return 0;
	}
}

sub get_dir_contents {
	my $directory = shift;
	my @logfile_array;
	opendir ( DIR, $directory ) or die $!;
	while ( my $file = readdir(DIR) ) {
		# Exclude dotted files like ".." and ".keep_www-servers_apache-2"
		unless ( $file =~ m/^\./ ) {
			push @logfile_array, $directory.$file;
		}
	}
	closedir(DIR);
	return @logfile_array;
}

