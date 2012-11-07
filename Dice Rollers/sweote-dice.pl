#!/bin/env perl
use strict;
use List::Util qw/max/;

my $RUNS = 1000000;

#s = success, f=failure, t=threat, a=advantage, T=triumph, D=despair

my @ABILITY =
  ( ['s'], ['a'], [ 's', 'a' ], [ 's', 's' ], ['a'], ['s'], [ 'a', 'a' ], [] );
my @PROFICIENCY = (
	[ 'a', 'a' ],
	['a'],
	[ 'a', 'a' ],
	[ 's', 'T' ],
	['s'],
	[ 's', 'a' ],
	['s'],
	[ 's', 'a' ],
	[ 's', 's' ],
	[ 's', 'a' ],
	[ 's', 's' ],
	[]
);
my @BOOST = ( ['a'], [ 's', 'a' ], [ 'a', 'a' ], ['s'], [], [] );
my @DIFFICULTY =
  ( ['t'], ['f'], [ 't', 'f' ], ['t'], [], [ 't', 't' ], [ 'f', 'f' ], ['t'] );
my @CHALLENGE = (
	[ 't', 't' ],
	['t'],
	[ 't', 't' ],
	['t'],
	[ 't', 'f' ],
	['f'],
	[ 't', 'f' ],
	['f'],
	[ 'f', 'f' ],
	[ 'f', 'D' ],
	[ 'f', 'f' ],
	[]
);
my @SETBACK = ( ['f'], ['t'], ['f'], ['t'], [], [] );

my @success;
my @advantage;

my %results;

foreach ( 1 .. $RUNS ) {
	my @result;
	push @result, @{ $ABILITY[ int( rand(@ABILITY) ) ] };
	push @result, @{ $PROFICIENCY[ int( rand(@PROFICIENCY) ) ] };
	push @result, @{ $PROFICIENCY[ int( rand(@PROFICIENCY) ) ] };
	$success[ grep( /s/,   @result ) ]++;
	$advantage[ grep( /a/, @result ) ]++;
	$results{ join( '', sort @result ) }++;
}
print_stats();

@success   = ();
@advantage = ();
%results   = ();
foreach ( 1 .. $RUNS ) {
	my @result;
	push @result, @{ $ABILITY[ int( rand(@ABILITY) ) ] };
	push @result, @{ $ABILITY[ int( rand(@ABILITY) ) ] };
	push @result, @{ $ABILITY[ int( rand(@ABILITY) ) ] };
	push @result, @{ $ABILITY[ int( rand(@ABILITY) ) ] };
	$success[ grep( /s/,   @result ) ]++;
	$advantage[ grep( /a/, @result ) ]++;
	$results{ join( '', sort @result ) }++;
}
print_stats();

exit();

@success   = ();
@advantage = ();
%results   = ();
foreach ( 1 .. $RUNS ) {
	my @result = @{ $ABILITY[ int( rand(@ABILITY) ) ] };
	push @result, @{ $BOOST[ int( rand(@BOOST) ) ] };
	$success[ grep( /s/,   @result ) ]++;
	$advantage[ grep( /a/, @result ) ]++;
	$results{ join( '', sort @result ) }++;
}
print_stats();

sub print_stats {
	for ( my $i = 0 ; $i < max( scalar @advantage, scalar @success ) ; $i++ )
	{
		print "$i\t" . $success[$i] . "\t" . $advantage[$i] . "\n";
	}
	foreach ( sort keys %results ) {
		print "$_\t" . $results{$_} . "\n";
	}
}
