#!/usr/bin/perl

use strict;
use warnings;
use FileHandle;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
#use Data::Dumper;

my %argument_hash;
my @unreadable_files;

# TODO:
# More comments, there are some whacky and awesome features here.
# Basic wildcard handling in filenames.
# POD documentation.
# Error and response code tracking for logs, implemented similar to ip tracking here.
# More multithreading? Perhaps for our file slurping.
# Error handling for @unreadable_files

# BASH nasty one-liner that inspired it all:
# LOGDIR='/var/log/apache2/'; time for logfile in $( ls -1 ${LOGDIR} ); do if [[ ${logfile} == *gz ]]; then zcat ${LOGDIR}${logfile}; else cat ${LOGDIR}${logfile}; fi; done  | perl -ne 'if ( $_ =~ m/([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})/ ) { print $1."\n"; }' | sort | uniq -c | sort -rn | head

# Process command line arguments in one big loop.
for ( my $argc = 0; defined $ARGV[$argc]; $argc++ ) {
	if ( $ARGV[$argc] =~ m/^\-?\-help$|^-h$|^-\?$/ ) {
		&help();
	} elsif ( $ARGV[$argc] =~ m/^\-\-count-ip$|^\-ip$/ ) {
		$argument_hash{'count-ip'} = 1;
	} elsif ( $ARGV[$argc] =~ m/^\-?\-jobs$|^-j$/ ) {
		 $argument_hash{'jobs'} = $ARGV[++$argc];
	} elsif ( $ARGV[$argc] =~ m/^\-?\-head$|^\-t$/ ) {
		$argument_hash{'top_results'} = $ARGV[++$argc];
	} elsif ( $ARGV[$argc] =~ m/^\-?\-pretty$|^-p$/ ) {
		$argument_hash{'pretty'} = 1;
	} elsif ( $ARGV[$argc] =~ m/^\-?\-verbose$|^-v$/ ) {
		$argument_hash{'verbose'} = 1;
	} elsif ( $ARGV[$argc] =~ m/^\-?\-debug$|^-d$/ ) {
	# I may end up removing this option.
		$argument_hash{'debug'} = 1;
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

# Sort out the files to process.
my @files_to_process;
if ( defined $argument_hash{'target'} 
and &target_exists( $argument_hash{'target'} ) 
and &target_is_readable( $argument_hash{'target'} ) ) {
	if ( &target_is_directory( $argument_hash{'target'} ) ) {
		if ( defined $argument_hash{'verbose'} ) {
			print "Directory detected: ".$argument_hash{'target'}."\n";
		}
		@files_to_process = &get_dir_contents( $argument_hash{'target'} );
	} else { 
		push @files_to_process, $argument_hash{'target'};
	}
} else {
	# This should not be necessary since we catch this in the submodules, but exists just for testing.
	print STDERR "Target does not exist or is not readable.\n";
	exit 1;
}


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
		if ( defined $argument_hash{'jobs'} ) {
			# Wrapping a submomdule in a submodule?! ...I know. Unfortunately, it is required by the package.
			$process_fork_manager->run_on_finish( sub { &integrate_child_hash( @_, \%ip_hash ) } );
			$process_fork_manager->start and next LOGFILE_PROCESSING_LOOP;
		}
		# To allow the parallel system to work, each child process needs its own hash.
		my %child_ip_hash;
		if ( defined $argument_hash{'verbose'} ) {
			print "Analyzing: ".$file."\n";
		}
		my $filehandle;
		if ( $file =~ m/gz$/ ) {
			# Pretty much straight from the module's manual.
			$filehandle = new IO::Uncompress::Gunzip $file
				or die "Gunzip failed: $GunzipError\n";
				# Find a way to put "next" with the error.
				# Also see if we can avoid the one-liner style here.
		} else {
			open $filehandle, '<', $file or push @unreadable_files, $file;
			# Again, we should avoid this one-liner style.
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
		# Closing the filehandle means we are done with this iteration of the logfile processing thread.
		if ( defined $argument_hash{'verbose'} ) {
			print "Complete: ".$file."\n";
		}
		# Send the collected data back to the parent thread.
		if ( defined $argument_hash{'jobs'} ) {
			$process_fork_manager->finish( 0, \%child_ip_hash );
		}
	}
	# Wait here for all the logfiles to finish processing.
	if ( defined $argument_hash{'jobs'} ) {
		$process_fork_manager->wait_all_children;
	}
	my $first_numeric_result = 1;
	my $numeric_buffer;
	# We should sort the results from largest number of occurrences to smallest. $a and $b are variables internal to "sort".
	for my $ip_address ( sort { $ip_hash{$b} <=> $ip_hash{$a} or $b cmp $a } keys %ip_hash ) {
		if ( not defined $argument_hash{'top_results'} or $argument_hash{'top_results'} > 0 ) {
			if ( defined $argument_hash{'pretty'} ) {
				if ( $first_numeric_result == 1 ) {
					$numeric_buffer = ( ( length $ip_hash{$ip_address} ) + 1 );
				}
				print " " x ( $numeric_buffer - length $ip_hash{$ip_address} );
			}
			print $ip_hash{$ip_address}." ".$ip_address."\n";
			# Only decrement if the user invoked the "--head" option. Otherwise, print all results ( 1 is always > 0 ).
			if ( defined $argument_hash{'top_results'} ) {
				$argument_hash{'top_results'}--;
			}
		} else {
			last;
		}
		$first_numeric_result = 0;
	}
}

sub help {
	my $help = "\n";
	$help .= "                  apache-log-scanner.pl\n";
	$help .= " Scan logfiles for specific information and count the occurrences of each.\n\n";
	$help .= " Usage: apache-log-scanner.pl [options] [logfile/directory]\n";
	$help .= "    or: apache-log-scanner.pl --count-ip /var/log/apache2/\n";
	$help .= "             Count IP address instances in all files inside /var/log/apache2/\n";
	$help .= "    or: apache-log-scanner.pl --count-ip --pretty --jobs 10 /var/log/apache2/\n";
	$help .= "             Count IP address instances, but use 10 process threads to scan logs and print a columnized result.\n";
	$help .= "\n";
	$help .= " Arguments:\n";
	$help .= "    --help, -h       Display this help menu and exit. Ignores all other options.\n";
	$help .= "    --count-ip, -ip  Display a list of ip addresses, descending by accurence in the logfile(s).\n";
	$help .= "    --head NUM, -t   Display only the top \"NUM\" results.\n";
	$help .= "    --jobs NUM, -j   Allow parallel processing up to the number of specified threads. Good if dealing with many logs.\n";
	$help .= "    --pretty, -p     Visually columnize the output.\n";
	$help .= "    --verbose, -v    Extra verbosity.\n";
	$help .= "\n";
	$help .= " The most up-to-date version of this script can be found here:\n";
	$help .= " https://github.com/linuxraptor/Perl-Arg-Practice/blob/master/apache-log-scanner.pl\n";
	print $help."\n";
	exit 0;
}

sub integrate_child_hash {
	my ($child_pid, $exit_code, $ident, $exit_signal, $core_dump, $child_hash_reference, $parent_hash_reference) = @_;
	if ( defined $child_hash_reference ) {
		for my $key ( keys %{$child_hash_reference} ) {
			if ( defined ${$parent_hash_reference}{$key} ) {
				${$parent_hash_reference}{$key} += ${$child_hash_reference}{$key};
			} else {
				${$parent_hash_reference}{$key} = ${$child_hash_reference}{$key};
			}
		}
	}
	# Do not return anything, the parent does not accept a value.
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

