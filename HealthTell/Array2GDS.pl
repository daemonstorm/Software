#!/bin/env perl
use strict;
use GDS2;
use List::Util qw(max min);
use List::MoreUtils qw/ uniq /;

my $file =
  'Mask Holes 330K.txt'
  ;    # name of the input file for which holes are on which mask
my $qc_file = 'QC Mask Holes 1254.txt';  # name of the QC region mask input file

my @spacing = ( 13, 11.25833 );   # horizontal and vertical spacing of the spots
my @area =
  ( 6482.080, 7475.220 )
  ;    # total area that the peptides should cover (width, height)

my @qc_area    = ( 10000, 10000 );
my @qc_spacing = ( 300,   259.80762 );
my $orange = 1;    # are these supposed to be orange-crated or box
my $offset = 6.5
  ; # if the peptides are orange-crated, how far in should the even rows be. This value is half the horizontal spacing as they are supposed to create equilateral triangles from the peptide spots

my $qc_offset = 150;

my ( $min, $max ) = ( 1, 1 );

my @qc_locations = (
	[ -93900, -35000 ],
	[ -93900, -25000 ],
	[ -93900, -15000 ],
	[ -93900, -5000 ],
	[ -93900, 5000 ],
	[ -93900, 15000 ],
	[ -93900, 25000 ],
	[ -93900, 35000 ],
	[ -78500, -53100 ],
	[ -78500, -43100 ],
	[ -78500, 43100 ],
	[ -78500, 53100 ],
	[ -68500, -63100 ],
	[ -68500, -53100 ],
	[ -68500, -43100 ],
	[ -68500, 43100 ],
	[ -68500, 53100 ],
	[ -68500, 63100 ],
	[ -43100, -81200 ],
	[ -43100, 81200 ],
	[ -30000, -93900 ],
	[ -30000, 93900 ],
	[ -20000, -93900 ],
	[ -20000, 93900 ],
	[ -10000, -93900 ],
	[ -10000, 93900 ],
	[ 0,      -93900 ],
	[ 0,      93900 ],
	[ 10000,  -93900 ],
	[ 10000,  93900 ],
	[ 20000,  -93900 ],
	[ 20000,  93900 ],
	[ 30000,  -93900 ],
	[ 30000,  93900 ],
	[ 43100,  -81200 ],
	[ 43100,  81200 ],
	[ 68500,  -63100 ],
	[ 68500,  -53100 ],
	[ 68500,  -43100 ],
	[ 68500,  43100 ],
	[ 68500,  53100 ],
	[ 68500,  63100 ],
	[ 78500,  -53100 ],
	[ 78500,  -43100 ],
	[ 78500,  43100 ],
	[ 78500,  53100 ],
	[ 93900,  -35300 ],
	[ 93900,  -25300 ],
	[ 93900,  -15300 ],
	[ 93900,  -5300 ],
	[ 93900,  5000 ],
	[ 93900,  15000 ],
	[ 93900,  25000 ],
	[ 93900,  35000 ]
);

my @peptides
  ; # an array to hold reference arrays of which masks each peptide spot uses (spots are just the numeric index of the main array)
my @masks
  ; # on each mask which spots should be opened up in this design. This is a reverse map of the @peptides array

if ( !$orange ) { $offset = 0; $qc_offset = 0; }

# create the GDS library. Interestingly, this doesn't delete the file if it already exists, but just overwrites the data in the file at the binary level. Useful when just needing to adjust a few parameters in the header areas of the lib.
my $gds2file = new GDS2( -fileName => ">test.gds" );

# don't forget to ->printEndlib() <-- note the lower 'l'
$gds2file->printInitLib( -name => "testlib" );

# Draw the spot feature in this area. It should be a hexanol object 8um in total size
$gds2file->printBgnstr( -name => "spot" );
$gds2file->printBoundary(
	-layer => 4,
	-xy    => [ 2, 0, 6, 0, 6, -1, 2, -1, 2, 0 ]
);
$gds2file->printBoundary(
	-layer => 4,
	-xy    => [ 1, -1, 7, -1, 7, -2, 1, -2, 1, -1 ]
);
$gds2file->printBoundary(
	-layer => 4,
	-xy    => [ 0, -2, 8, -2, 8, -6, 0, -6, 0, -2 ]
);
$gds2file->printBoundary(
	-layer => 4,
	-xy    => [ 1, -6, 7, -6, 7, -7, 1, -7, 1, -6 ]
);
$gds2file->printBoundary(
	-layer => 4,
	-xy    => [ 2, -7, 6, -7, 6, -8, 2, -8, 2, -7 ]
);
$gds2file->printEndstr();

# Finished creating the spot feature

# create a default 1um box that can be scaled, arrayed, etc... in other parts of the library
$gds2file->printBgnstr( -name => "1um_box" );
$gds2file->printBoundary(
	-layer => 4,
	-xy    => [ -0.5, 0.5, 0.5, 0.5, 0.5, -0.5, -0.5, -0.5, -0.5, 0.5 ]
);
$gds2file->printEndstr();

# finished creating the 1um box

# create the auto alignment mark for the OAI Autoalignment system. the exposed mark is a series of arrow heads that should surround a diamond etched into the wafer.
$gds2file->printBgnstr( -name => "auto_align_arrow" );
$gds2file->printBoundary(
	-layer => 4,
	-xy    => [
		-50,     150,    50,  150,     50,      50,
		-50,     50,     -50, 96.874,  -28.143, 96.874,
		-15.627, 84.358, 0,   99.985,  15.627,  84.358,
		28.143,  96.874, 0,   125.017, -28.143, 96.874,
		-50,     96.874
	]
);
$gds2file->printEndstr();

$gds2file->printBgnstr( -name => "align_exposure_auto" );
$gds2file->printSref( -name => "auto_align_arrow", -xy => [ 0, 0 ] );
$gds2file->printSref(
	-name  => "auto_align_arrow",
	-xy    => [ 0, 0 ],
	-angle => 90
);
$gds2file->printSref(
	-name  => "auto_align_arrow",
	-xy    => [ 0, 0 ],
	-angle => 180
);
$gds2file->printSref(
	-name  => "auto_align_arrow",
	-xy    => [ 0, 0 ],
	-angle => 270
);

$gds2file->printAref(
	-name    => "1um_box",
	-xy      => [ -100, -100, 300, -100, -100, 300 ],
	-columns => 2,
	-rows    => 2,
	-mag     => 100
);

$gds2file->printSref( -name => "1um_box", -xy => [ 0, 0 ], -mag => 100 );
$gds2file->printEndstr();

# end of the auto-alignment mark for the OAI system.

# create the manual alignment mark for the OAI system
$gds2file->printBgnstr( -name => "align_exposure_manual" );
$gds2file->printBoundary(
	-layer => 4,
	-xy    => [
		-1000,  -1000,  1000,   -1000, 1000,  1000,  -137.5, 1000,
		-137.5, 0,      -125,   12.5,  -53.5, 12.5,  -53.5,  46.5,
		-75,    46.5,   -75,    53.5,  -53.5, 53.5,  -53.5,  75,
		-46.5,  75,     -46.5,  53.5,  -12.5, 53.5,  -12.5,  125,
		0,      137.5,  12.5,   125,   12.5,  53.5,  46.5,   53.5,
		46.5,   75,     53.5,   75,    53.5,  53.5,  75,     53.5,
		75,     46.5,   53.5,   46.5,  53.5,  12.5,  125,    12.5,
		137.5,  0,      125,    -12.5, 53.5,  -12.5, 53.5,   -46.5,
		75,     -46.5,  75,     -53.5, 53.5,  -53.5, 53.5,   -75,
		46.5,   -75,    46.5,   -53.5, 12.5,  -53.5, 12.5,   -125,
		0,      -137.5, -12.5,  -125,  -12.5, -53.5, -46.5,  -53.5,
		-46.5,  -75,    -53.5,  -75,   -53.5, -53.5, -75,    -53.5,
		-75,    -46.5,  -53.5,  -46.5, -53.5, -12.5, -125,   -12.5,
		-137.5, 0,      -137.5, 1000,  -1000, 1000,  -1000,  -1000
	]
);

$gds2file->printSref(
	-name => "1um_box",
	-xy   => [ -29.500, -29.500 ],
	-mag  => 34,
);
$gds2file->printSref(
	-name => "1um_box",
	-xy   => [ -29.500, 29.500 ],
	-mag  => 34,
);
$gds2file->printSref(
	-name => "1um_box",
	-xy   => [ 29.500, -29.500 ],
	-mag  => 34,
);
$gds2file->printSref(
	-name => "1um_box",
	-xy   => [ 29.500, 29.500 ],
	-mag  => 34,
);
$gds2file->printSref( -name => "1um_box", -xy => [ 0, 0 ], -mag => 12.5 );
$gds2file->printEndstr();

# Finished creating the manual alignment mark

@peptides = ();
@masks    = ();
open FH, $qc_file;
while ( my $line = <FH> ) {
	chomp($line);
	my @data = sort { $a <=> $b } uniq( split( /,/, $line ) );
	push @peptides, \@data;
	$min = min( $min, $data[0] );
	$max = max( $max, $data[$#data] );
}

print @peptides . "\n";

# determine the limit of the number of rows and columns that the area can hold. Really only the number of columns is used in later steps. Should consider throwing an error if the number of spots exceeds the allowed spacing
my $rows    = int( $qc_area[1] / $qc_spacing[1] );
my $columns = int( $qc_area[0] / $qc_spacing[0] );

print "$rows\t$columns\n";

$gds2file->printBgnstr( -name => sprintf( "%s", 'qc_mask_all' ) );

for ( my $spot = 0 ; $spot < $rows * $columns ; $spot++ ) {
	my $x = int( $spot % $columns ) * $qc_spacing[0];
	$x += +$qc_offset if ( int( $spot / $columns ) % 2 );
	my $y = -1 * int( $spot / $columns ) * $qc_spacing[1];
	$gds2file->printSref(
		-name => "spot",
		-xy   => [ $x, $y ],
		-mag  => 25
	);
}

$gds2file->printEndstr();

$gds2file->printBgnstr( -name => sprintf( "%s", 'qc_chip_all' ) );
$gds2file->printSref(
	-name => sprintf( "%s",      'qc_mask_all' ),
	-xy   => [ -$qc_area[0] / 2, $qc_area[1] / 2 ]
);
$gds2file->printEndstr();

foreach my $i ( 0 .. $#peptides ) {
	foreach my $mask ( @{ $peptides[$i] } ) {
		push @{ $masks[ $mask - $min ] }, $i if ( $mask =~ /^[\d]+$/ );
	}
}

my $count = 0;
foreach my $mask (@masks) {
	if ( defined($mask) ) {
		print "$count\n";
		if ( @{$mask} > 0 ) {

			# draw each mask layer with the needed spots based on the input file
			$gds2file->printBgnstr(
				-name => sprintf( "%s%03d", 'qc_mask_', $count ) );

			foreach my $spot ( @{$mask} ) {
				my $x = int( $spot % $columns ) * $qc_spacing[0];
				$x += +$qc_offset if ( int( $spot / $columns ) % 2 );
				my $y = -1 * int( $spot / $columns ) * $qc_spacing[1];
				$gds2file->printSref(
					-name => "spot",
					-xy   => [ $x, $y ],
					-mag  => 25
				);
			}

			$gds2file->printEndstr();

			# done drawing the mask for this layer

# laying down the mask onto the "chip" area of the design. this centers the layout.
			$gds2file->printBgnstr(
				-name => sprintf( "%s%03d", 'qc_chip_', $count ) );
			$gds2file->printSref(
				-name => sprintf( "%s%03d",  'qc_mask_', $count ),
				-xy   => [ -$qc_area[0] / 2, $qc_area[1] / 2 ]
			);
			$gds2file->printEndstr();

			# end of placing the mask on the chip.

		}
	}
	$count++;
}

@peptides = ();
@masks    = ();

# determine the limit of the number of rows and columns that the area can hold. Really only the number of columns is used in later steps. Should consider throwing an error if the number of spots exceeds the allowed spacing
my $rows    = int( $area[1] / $spacing[1] );
my $columns = int( $area[0] / $spacing[0] );

print "$rows\t$columns\n";

$gds2file->printBgnstr( -name => sprintf( "%s", 'mask_all' ) );

for ( my $spot = 0 ; $spot < $rows * $columns ; $spot++ ) {
	my $x = int( $spot % $columns ) * $spacing[0];
	$x += +$offset if ( int( $spot / $columns ) % 2 );
	my $y = -1 * int( $spot / $columns ) * $spacing[1];
	$gds2file->printSref( -name => "spot", -xy => [ $x, $y ] );
}

$gds2file->printEndstr();

$gds2file->printBgnstr( -name => sprintf( "%s", 'chip_all' ) );
$gds2file->printSref(
	-name => sprintf( "%s",   'mask_all' ),
	-xy   => [ -$area[0] / 2, $area[1] / 2 ]
);
$gds2file->printEndstr();

$gds2file->printBgnstr( -name => sprintf( "%s", 'slide_all' ) );
$gds2file->printAref(
	-name => sprintf( "%s", 'chip_all' ),
	-xy   => [
		-8056.880,                -31497.27,
		3 * 8031.480 + -8056.880, -31497.27,
		-8056.880,                8 * 8999.220 + -31497.27
	],
	-columns => 3,
	-rows    => 8
);
$gds2file->printEndstr();

# done laying out the chips on the slide for this layer.

# create the overall layer with the slides and alignment marks and QC spots
$gds2file->printBgnstr( -name => sprintf( "%s", 'layer_all' ) );
$gds2file->printAref(
	-name => sprintf( "%s", 'slide_all' ),
	-xy => [ -76200.000, 0, 2 * 152400.000 + -76200.000, 0, -76200.000, 0 ],
	-columns => 2,
	-rows    => 1
);
$gds2file->printAref(
	-name => sprintf( "%s", 'slide_all' ),
	-xy   => [
		-50800.000,                  38100.000,
		2 * 101600.000 + -50800.000, 38100.000,
		-50800.000,                  2 * -76200.000 + 38100.000
	],
	-columns => 2,
	-rows    => 2
);
$gds2file->printAref(
	-name => sprintf( "%s", 'slide_all' ),
	-xy      => [ 0, -76200.000, 0, 7 * 25400 - 76200, 0, -76200.000 ],
	-columns => 7,
	-rows    => 1,
	-angle   => 90,
);

$gds2file->printSref(
	-name => "align_exposure_auto",
	-xy   => [ -88900.000, 0 ]
);
$gds2file->printSref(
	-name => "align_exposure_auto",
	-xy   => [ 88900.000, 0 ]
);
$gds2file->printSref(
	-name => "align_exposure_manual",
	-xy   => [ -55550.000, 0 ]
);
$gds2file->printSref(
	-name => "align_exposure_manual",
	-xy   => [ 55550.000, 0 ]
);

foreach my $xy (@qc_locations) {
	$gds2file->printSref(
		-name => sprintf( "%s", 'qc_chip_all' ),
		-xy   => $xy
	);
}

$gds2file->printEndstr();

# create the overall layer with the slides and alignment marks and QC spots
$gds2file->printBgnstr( -name => sprintf( "%s", 'layer_qc_only' ) );
$gds2file->printSref(
	-name => "align_exposure_auto",
	-xy   => [ -88900.000, 0 ]
);
$gds2file->printSref(
	-name => "align_exposure_auto",
	-xy   => [ 88900.000, 0 ]
);
$gds2file->printSref(
	-name => "align_exposure_manual",
	-xy   => [ -55550.000, 0 ]
);
$gds2file->printSref(
	-name => "align_exposure_manual",
	-xy   => [ 55550.000, 0 ]
);

foreach my $xy (@qc_locations) {
	$gds2file->printSref(
		-name => sprintf( "%s", 'qc_chip_all' ),
		-xy   => $xy
	);
}

$gds2file->printEndstr();

open FH, $file;
while ( my $line = <FH> ) {
	chomp($line);
	my @data = sort { $a <=> $b } uniq( split( /,/, $line ) );
	push @peptides, \@data;
	$min = min( $min, $data[0] );
	$max = max( $max, $data[$#data] );
}

print @peptides . "\n";

foreach my $i ( 0 .. $#peptides ) {
	foreach my $mask ( @{ $peptides[$i] } ) {
		push @{ $masks[ $mask - $min ] }, $i if ( $mask =~ /^[\d]+$/ );
	}
}

my $count = 0;
foreach my $mask (@masks) {
	if ( defined($mask) ) {
		print "$count\n";
		if ( @{$mask} > 0 ) {

			# draw each mask layer with the needed spots based on the input file
			$gds2file->printBgnstr(
				-name => sprintf( "%s%03d", 'mask', $count ) );

			foreach my $spot ( @{$mask} ) {
				my $x = int( $spot % $columns ) * $spacing[0];
				$x += +$offset if ( int( $spot / $columns ) % 2 );
				my $y = -1 * int( $spot / $columns ) * $spacing[1];
				$gds2file->printSref( -name => "spot", -xy => [ $x, $y ] );
			}

			$gds2file->printEndstr();

			# done drawing the mask for this layer

# laying down the mask onto the "chip" area of the design. this centers the layout.
			$gds2file->printBgnstr(
				-name => sprintf( "%s%03d", 'chip', $count ) );
			$gds2file->printSref(
				-name => sprintf( "%s%03d", 'mask', $count ),
				-xy   => [ -$area[0] / 2,   $area[1] / 2 ]
			);
			$gds2file->printEndstr();

			# end of placing the mask on the chip.

			# array the chips onto the slide layout
			$gds2file->printBgnstr(
				-name => sprintf( "%s%03d", 'slide', $count ) );
			$gds2file->printAref(
				-name => sprintf( "%s%03d", 'chip', $count ),
				-xy   => [
					-8056.880,                -31497.27,
					3 * 8031.480 + -8056.880, -31497.27,
					-8056.880,                8 * 8999.220 + -31497.27
				],
				-columns => 3,
				-rows    => 8
			);
			$gds2file->printEndstr();

			# done laying out the chips on the slide for this layer.

	 # create the overall layer with the slides and alignment marks and QC spots
			$gds2file->printBgnstr(
				-name => sprintf( "%s%03d", 'layer', $count ) );
			$gds2file->printAref(
				-name => sprintf( "%s%03d", 'slide', $count ),
				-xy   => [
					-76200.000,                  0,
					2 * 152400.000 + -76200.000, 0,
					-76200.000,                  0
				],
				-columns => 2,
				-rows    => 1
			);
			$gds2file->printAref(
				-name => sprintf( "%s%03d", 'slide', $count ),
				-xy   => [
					-50800.000,                  38100.000,
					2 * 101600.000 + -50800.000, 38100.000,
					-50800.000,                  2 * -76200.000 + 38100.000
				],
				-columns => 2,
				-rows    => 2
			);
			$gds2file->printAref(
				-name => sprintf( "%s%03d", 'slide', $count ),
				-xy => [ 0, -76200.000, 0, 7 * 25400 - 76200, 0, -76200.000 ],
				-columns => 7,
				-rows    => 1,
				-angle   => 90,
			);

			$gds2file->printSref(
				-name => "align_exposure_auto",
				-xy   => [ -88900.000, 0 ]
			);
			$gds2file->printSref(
				-name => "align_exposure_auto",
				-xy   => [ 88900.000, 0 ]
			);
			$gds2file->printSref(
				-name => "align_exposure_manual",
				-xy   => [ -55550.000, 0 ]
			);
			$gds2file->printSref(
				-name => "align_exposure_manual",
				-xy   => [ 55550.000, 0 ]
			);

			if ( $count < 142 ) {
				foreach my $xy (@qc_locations) {
					$gds2file->printSref(
						-name => sprintf( "%s%03d", 'qc_chip_', $count ),
						-xy   => $xy
					);
				}
			}

			$gds2file->printEndstr();

			# Finished writing the actual mask layer
		}
	}
	$count++;
}

# ending the library
$gds2file->printEndlib();

# closing the file
$gds2file->close();
