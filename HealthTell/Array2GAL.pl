#!/bin/env perl
use strict;
use List::Util qw(max min);
use List::MoreUtils qw/ uniq /;
use File::Basename;

my $mask_use = 'HTChipv4-45.txt';

my $file =
  'Mask Holes 330K.txt'
  ;    # name of the input file for which holes are on which mask
my $qc_file = 'QC Mask Holes 1254.txt';  # name of the QC region mask input file

my ($basename, $path, $suffix)=fileparse($mask_use, qr/\.[^.]*/);

my @output = ( 'qc_330k_'.$basename.'.gal', '330k_'.$basename.'.gal' );

my @spacing = ( 13, 11.25833 );   # horizontal and vertical spacing of the spots
my @area =
  ( 6482.080, 7475.220 )
  ;    # total area that the peptides should cover (width, height)

my @qc_area    = ( 10000, 10000 );
my @qc_spacing = ( 300,   259.80762 );
my $orange = 1;    # are these supposed to be orange-crated or box
my @peptides
  ; # an array to hold reference arrays of which masks each peptide spot uses (spots are just the numeric index of the main array)
my @masks
  ; # on each mask which spots should be opened up in this design. This is a reverse map of the @peptides array

my @mask_order;
my @aa_order;

open FH, $mask_use;
while ( my $line = <FH> ) {
	chomp($line);
	my @data = split( /[\s,]/, $line );
	push @mask_order, $data[0];
	push @aa_order,   $data[1];
}

@peptides = ();
@masks    = ();
open FH, $qc_file;
while ( my $line = <FH> ) {
	chomp($line);
	my @data = sort { $a <=> $b } uniq( split( /,/, $line ) );
	push @peptides, \@data;
}

print @peptides . "\n";

# determine the limit of the number of rows and columns that the area can hold. Really only the number of columns is used in later steps. Should consider throwing an error if the number of spots exceeds the allowed spacing
my $rows    = int( $qc_area[1] / $qc_spacing[1] );
my $columns = int( $qc_area[0] / $qc_spacing[0] );

print "$rows\t$columns\n";

open OUT, ">" . $output[0];
print OUT 'ATF	1.0
5	5
Type=GenePix ArrayList V1.0
BlockCount=1
BlockType=3
WaferProcess='.$basename."\n";
print OUT "Block1= 100,100,200,$columns,"
  . $qc_spacing[0]
  . ",$rows,"
  . $qc_spacing[1] . "\n";
print OUT "Block\tRow\tColumn\tID\tName\n";

for ( my $spot = 0 ; $spot < $rows * $columns ; $spot++ ) {
	my $name;
	for ( my $mask = 0 ; $mask < @mask_order ; $mask++ ) {
		if ( $mask_order[$mask] =~ /all|qc-only/i ) {
			$name = $aa_order[$mask].$name;
			next;
		}
		my $number = $mask_order[$mask];
		if ( grep( /^$number$/, @{ $peptides[$spot] } ) ) {
			$name = $aa_order[$mask].$name;
		}
	}
	#$name = join('',reverse(split(//,$name)));
	$name = 'empty' if ( $name =~ /^$/ );
	my $x = int( $spot % $columns ) + 1;
	my $y = int( $spot / $columns ) + 1;
	printf( OUT '%d	%d	%d	%s	%s
', 1, $y, $x, $name, $name
	);
}
@peptides = ();
@masks    = ();

open FH, $file;
while ( my $line = <FH> ) {
	chomp($line);
	my @data = sort { $a <=> $b } uniq( split( /,/, $line ) );
	push @peptides, \@data;
}

print @peptides . "\n";

# determine the limit of the number of rows and columns that the area can hold. Really only the number of columns is used in later steps. Should consider throwing an error if the number of spots exceeds the allowed spacing
my $rows    = int( $area[1] / $spacing[1] );
my $columns = int( $area[0] / $spacing[0] );

print "$rows\t$columns\n";

open OUT, ">" . $output[1];
print OUT 'ATF	1.0
5	5
Type=GenePix ArrayList V1.0
BlockCount=1
BlockType=3
WaferProcess='.$basename."\n";

print OUT "Block1= 100,100,10,$columns,"
  . $spacing[0]
  . ",$rows,"
  . $spacing[1] . "\n";
print OUT "Block\tRow\tColumn\tID\tName\n";

for ( my $spot = 0 ; $spot < $rows * $columns ; $spot++ ) {
	last if ( $spot > $#peptides );
	my $name;
	for ( my $mask = 0 ; $mask < @mask_order ; $mask++ ) {
		if ( lc($mask_order[$mask]) eq 'all' ) {
			$name = $aa_order[$mask].$name;
			next;
		}
		my $number = $mask_order[$mask];
		if ( grep( /^$number$/, @{ $peptides[$spot] } ) ) {
			$name = $aa_order[$mask].$name;
		}

	}
	#$name = join('',reverse(split(//,$name)));
	$name = 'empty' if ( $name =~ /^$/ );
	my $x = int( $spot % $columns ) + 1;
	my $y = int( $spot / $columns ) + 1;
	printf( OUT '%d	%d	%d	%s	%s
', 1, $y, $x, $name, $name
	);
}
