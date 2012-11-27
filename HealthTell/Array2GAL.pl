#!/bin/env perl
use strict;
use List::Util qw(max min);
use List::MoreUtils qw/ uniq /;
use File::Basename;
use Getopt::Long;

my $mask_use = 'HTChipv4-45.txt';
my $mask_version = 4;    # the default version to design the GAL files for

my ( $script, $script_dir ) = fileparse(__FILE__);

my ( $help, $verbose );

GetOptions(
	"process=s" => \$mask_use,
	"version=i" => \$mask_version,
	"help"      => \$help,
	"verbose+"  => $verbose,
);

if ( $mask_use eq '' || !-e $mask_use ) {
	die("Process file not found or not set\n");
}

my ( $basename, $path, $suffix ) = fileparse( $mask_use, qr/\.[^.]*/ );

my @mask_order;
my @aa_order;

open FH, $mask_use or die("Could not open $mask_use for reading\n");
while ( my $line = <FH> ) {
	chomp($line);
	my @data = split( /[\s,]/, $line );
	push @mask_order, $data[0];
	push @aa_order,   $data[1];
}

if ( $mask_version == 4 ) {
	array_v4();
}
elsif ( $mask_version == 6 ) {
	array_v6();
}
else {
	die("version not set to a valid value to create GAL files from\n");
}

sub array_v4 {

	my $file =
	  sprintf( '%sv4/%s', $script_dir, 'Mask Holes 330K.txt' )
	  ;    # name of the input file for which holes are on which mask
	my $qc_file =
	  sprintf( '%sv4/%s', $script_dir, 'QC Mask Holes 1254.txt' )
	  ;    # name of the QC region mask input file

	my @output =
	  ( 'qc_330k_' . $basename . '.gal', '330k_' . $basename . '.gal' );

	my @spacing =
	  ( 13, 11.25833 );    # horizontal and vertical spacing of the spots
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
WaferProcess=' . $basename . "\n";
	print OUT "Block1= 100,100,200,$columns,"
	  . $qc_spacing[0]
	  . ",$rows,"
	  . $qc_spacing[1] . "\n";
	print OUT "Block\tRow\tColumn\tID\tName\n";

	for ( my $spot = 0 ; $spot < $rows * $columns ; $spot++ ) {
		my $name;
		for ( my $mask = 0 ; $mask < @mask_order ; $mask++ ) {
			if ( $mask_order[$mask] =~ /all|qc-only/i ) {
				$name = $aa_order[$mask] . $name;
				next;
			}
			my $number = $mask_order[$mask];
			if ( grep( /^$number$/, @{ $peptides[$spot] } ) ) {
				$name = $aa_order[$mask] . $name;
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
WaferProcess=' . $basename . "\n";

	print OUT "Block1= 100,100,10,$columns,"
	  . $spacing[0]
	  . ",$rows,"
	  . $spacing[1] . "\n";
	print OUT "Block\tRow\tColumn\tID\tName\n";

	for ( my $spot = 0 ; $spot < $rows * $columns ; $spot++ ) {
		last if ( $spot > $#peptides );
		my $name;
		for ( my $mask = 0 ; $mask < @mask_order ; $mask++ ) {
			if ( lc( $mask_order[$mask] ) eq 'all' ) {
				$name = $aa_order[$mask] . $name;
				next;
			}
			my $number = $mask_order[$mask];
			if ( grep( /^$number$/, @{ $peptides[$spot] } ) ) {
				$name = $aa_order[$mask] . $name;
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
}

sub array_v6 {
	my $file =
	  sprintf( '%sv6/%s', $script_dir, 'Mask Holes 330K.txt' )
	  ;    # name of the input file for which holes are on which mask

	my @spacing =
	  ( 300, 259.8075, 75, 64.9519, 13, 11.25833 )
	  ;    # horizontal and vertical spacing of the spots

	my @diameter = ( 200, 50, 8 );
	my @area =
	  ( 6482.080, 7475.220 )
	  ;    # total area that the peptides should cover (width, height)

	my $orange = 1;    # are these supposed to be orange-crated or box

	# if the peptides are orange-crated, how far in should the even rows be.
	# This value is half the horizontal spacing as they are supposed to create
	# equilateral triangles from the peptide spots
	my @offset = ( 150, 37.5, 6.5 );

	my @peptides;

	open FH, $file;
	while ( my $line = <FH> ) {
		chomp($line);
		my @data = sort { $a <=> $b } uniq( split( /,/, $line ) );
		push @peptides, \@data;
	}

	print @peptides . "\n";

	foreach my $i ( 0 .. 23 ) {
		my $output = sprintf( '330k_%s_%03d.gal', $basename, $i + 1 );

# determine the limit of the number of rows and columns that the area can hold. Really only the number of columns is used in later steps. Should consider throwing an error if the number of spots exceeds the allowed spacing
		my @space =
		  ( $spacing[ 2 * int( $i / 9 ) ], $spacing[ 2 * int( $i / 9 ) + 1 ] );

		my $rows    = int( $area[1] / $space[1] );
		my $columns = int( $area[0] / $space[0] );

		print "$rows\t$columns\n";

		open OUT, ">" . $output;
		print OUT 'ATF	1.0
5	5
Type=GenePix ArrayList V1.0
BlockCount=1
BlockType=3
WaferProcess=' . $basename . "\n";

		print OUT "Block1= 100,100,"
		  . $diameter[ int( $i / 9 ) ]
		  . ",$columns,"
		  . $space[0]
		  . ",$rows,"
		  . $space[1] . "\n";
		print OUT "Block\tRow\tColumn\tID\tName\n";

		for ( my $spot = 0 ; $spot < $rows * $columns ; $spot++ ) {
			last if ( $spot > $#peptides );
			my $name;
			for ( my $mask = 0 ; $mask < @mask_order ; $mask++ ) {
				my $number = $mask_order[$mask];
				my @hits   =
				  grep { int( $_ / 24 ) == $number } @{ $peptides[$spot] };
				foreach (@hits) {
					if ( $_ % 24 == $i )
					{
						$name = $aa_order[$mask] . $name;
					}
				}
			}
			$name = 'empty' if ( $name =~ /^$/ );
			my $x = int( $spot % $columns ) + 1;
			my $y = int( $spot / $columns ) + 1;
			printf( OUT '%d	%d	%d	%s	%s
', 1, $y, $x, $name, $name
			);
		}
	}
}
