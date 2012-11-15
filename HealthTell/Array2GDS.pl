#!/bin/env perl
use strict;
use GDS2;
use List::Util qw(max min);
use List::MoreUtils qw/ uniq /;

my $file    = shift;
my @spacing =
  ( 300, 259.8075, 75, 64.9519, 13, 11.25833 )
  ;    # horizontal and vertical spacing of the spots
my @mag = ( 25, 12.5, 1 );

my @area =
  ( 6482.080, 7475.220 )
  ;    # total area that the peptides should cover (width, height)

my $orange = 1;    # are these supposed to be orange-crated or box

# if the peptides are orange-crated, how far in should the even rows be.
# This value is half the horizontal spacing as they are supposed to create
# equilateral triangles from the peptide spots
my @offset = ( 150, 37.5, 6.5 );

# create the GDS library. Interestingly, this doesn't delete the file if it
# already exists, but just overwrites the data in the file at the binary level.
# Useful when just needing to adjust a few parameters in the header areas of
# the lib.
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

# create a default 1um box that can be scaled, arrayed, etc... in other parts
# of the library
$gds2file->printBgnstr( -name => "1um_box" );
$gds2file->printBoundary(
	-layer => 4,
	-xy    => [ -0.5, 0.5, 0.5, 0.5, 0.5, -0.5, -0.5, -0.5, -0.5, 0.5 ]
);
$gds2file->printEndstr();

# finished creating the 1um box

# create the auto alignment mark for the OAI Autoalignment system. the exposed
# mark is a series of arrow heads that should surround a diamond etched into
# the wafer.
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

# create the chip alignment marks for MALDI
$gds2file->printBgnstr( -name => "align_triangle" );
$gds2file->printBoundary(
	-layer => 4,
	-xy    => [ 0, 100, 75, -100, -75, -100, 0, 100 ]
);
$gds2file->printEndstr();

$gds2file->printBgnstr( -name => "align_diamond" );
$gds2file->printBoundary(
	-layer => 4,
	-xy    => [ 0, 100, 75, 0, 0, -100, -75, 0, 0, 100 ]
);
$gds2file->printEndstr();

$gds2file->printBgnstr( -name => "align_cross" );
$gds2file->printBoundary(
	-layer => 4,
	-xy    => [
		-15, 100, 15,  100,  15,  15,   75,  15,  75,  -15,
		15,  -15, 15,  -100, -15, -100, -15, -15, -75, -15,
		-75, 15,  -15, 15,   -15, 75
	]
);
$gds2file->printEndstr();

$gds2file->printBgnstr( -name => "align_chip" );
$gds2file->printSref(
	-name => "align_triangle",
	-xy   => [ -$area[0] / 2 - 100, $area[1] / 2 - 100 ]
);
$gds2file->printSref(
	-name => "align_diamond",
	-xy   => [ $area[0] / 2 + 100, $area[1] / 2 - 100 ]
);
$gds2file->printSref(
	-name => "align_cross",
	-xy   => [ -$area[0] / 2 - 100, -$area[1] / 2 + 100 ]
);
$gds2file->printEndstr();

$gds2file->printBgnstr( -name => "align_slide" );
$gds2file->printAref(
	-name => "align_chip",
	-xy   => [
		-8056.880,                -31497.27,
		3 * 8031.480 + -8056.880, -31497.27,
		-8056.880,                8 * 8999.220 + -31497.27
	],
	-columns => 3,
	-rows    => 8
);
$gds2file->printEndstr();

# create the overall layer with the slides and alignment marks and QC spots
$gds2file->printBgnstr( -name => "align_layer" );
$gds2file->printAref(
	-name => "align_slide",
	-xy   => [ -76200.000, 0, 2 * 152400.000 + -76200.000, 0, -76200.000, 0 ],
	-columns => 2,
	-rows    => 1
);
$gds2file->printAref(
	-name => "align_slide",
	-xy   => [
		-50800.000,                  38100.000,
		2 * 101600.000 + -50800.000, 38100.000,
		-50800.000,                  2 * -76200.000 + 38100.000
	],
	-columns => 2,
	-rows    => 2
);
$gds2file->printAref(
	-name    => "align_slide",
	-xy      => [ 0, -76200.000, 0, 7 * 25400 - 76200, 0, -76200.000 ],
	-columns => 7,
	-rows    => 1,
	-angle   => 270,
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
$gds2file->printEndstr();

# Finished writing the actual mask layer

# determine the limit of the number of rows and columns that the area can hold.
# Really only the number of columns is used in later steps. Should consider
# throwing an error if the number of spots exceeds the allowed spacing

my @masks;
open FH, $file;
my $count =0;
while ( my $line = <FH> ) {
	chomp($line);
	my @data = sort { $a <=> $b } uniq( split( /,/, $line ) );
	foreach (@data){
		push @{$masks[$_]},$count;
	}
}

my $count = 0;
foreach my $mask (@masks) {
	if ( defined($mask) ) {
		print "$count\n";

		my @space = (
			$spacing[ 2*int( ( $count % 24 ) / 9 ) ],
			$spacing[ 2*int( ( $count % 24 ) / 9 ) + 1 ]
		);

		my $rows    = int( $area[1] / $space[1] );
		my $columns = int( $area[0] / $space[0] );

		if ( @{$mask} >= 0 ) {

			# draw each mask layer with the needed spots based on the input file
			$gds2file->printBgnstr(
				-name => sprintf( " % s%03d", 'mask', $count ) );

			foreach my $spot ( @{$mask} ) {
				my $x = int( $spot % $columns ) * $space[0];
				$x += $offset[ int( ( $count % 24 ) / 9 ) ]
				  if ( int( $spot / $columns ) % 2 );
				my $y = -1 * int( $spot / $columns ) * $space[1];
				$gds2file->printSref(
					-name => "spot",
					-xy   => [ $x, $y ],
					-mag  => $mag[ int( ( $count % 24 ) / 9 ) ]
				);
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

		}
	}
	$count++;
}

# array the chips onto the slide layout
for ( my $i = 0 ; $i < @masks / 24 ; $i++ ) {
	$gds2file->printBgnstr( -name => sprintf( "%s%03d", 'slide', $i ) );
	for ( my $j = 0 ; $j < 24 ; $j++ ) {
		if ( defined( $masks[ $i * 24 + $j ] ) ) {
			printf( "laying out chip: %03d\n", $i * 24 + $j );
			$gds2file->printSref(
				-name => sprintf( "%s%03d", 'chip', $i * 24 + $j ),
				-xy   => [
					-8056.880 + ( $j % 3 ) * 8031.480,
					-31497.27 + ( $j % 8 ) * 8999.220
				],
			);
		}
	}
	$gds2file->printEndstr();

	# done laying out the chips on the slide for this layer.

	# create the overall layer with the slides and alignment marks and QC spots
	$gds2file->printBgnstr( -name => sprintf( "%s%03d", 'layer', $i ) );
	$gds2file->printAref(
		-name => sprintf( "%s%03d", 'slide', $i ),
		-xy => [ -76200.000, 0, 2 * 152400.000 + -76200.000, 0, -76200.000, 0 ],
		-columns => 2,
		-rows    => 1
	);
	$gds2file->printAref(
		-name => sprintf( "%s%03d", 'slide', $i ),
		-xy   => [
			-50800.000,                  38100.000,
			2 * 101600.000 + -50800.000, 38100.000,
			-50800.000,                  2 * -76200.000 + 38100.000
		],
		-columns => 2,
		-rows    => 2
	);
	$gds2file->printAref(
		-name => sprintf( "%s%03d", 'slide', $i ),
		-xy      => [ 0, -76200.000, 0, 7 * 25400 - 76200, 0, -76200.000 ],
		-columns => 7,
		-rows    => 1,
		-angle   => 270,
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

	$gds2file->printEndstr();
}

# Finished writing the actual mask layer

# ending the library
$gds2file->printEndlib();

# closing the file
$gds2file->close();
