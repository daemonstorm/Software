#!/bin/env perl
use strict;
use threads;
use Thread::Queue;
use threads::shared;
use Wx;

use lib '.';
use Microarray::gpr;

=head1 NAME

QCPC - Quality Control Process Control Application

=head1 SYNOPSIS

QCPC is used to compare Microarray Data across samples. This is useful to 
determine consistency of data across Microarray slides. QCPC outputs data to an
Excel XLSX formatted file to show graphs and Pearson Correlation statistics 
about the various arrays.
Depending on if QCPC is built with 64-bit Perl and WxWidgets or 32-bit versions
determines the limit on how many and how large of a series of GPR files QCPC
can compare.

=head1 DESCRIPTION

=head1 COPYRIGHT

Copyright 2012 Kevin Brown.

Permission is granted to copy, distribute and/or modify this 
document under the terms of the GNU Free Documentation 
License, Version 2.0 or any later version published by the 
Free Software Foundation; with no Invariant Sections, with 
no Front-Cover Texts, and with no Back-Cover Texts.

=cut

my $DONE_EVENT : shared = Wx::NewEventType();
#my $EXCEL : shared;

my $wx = QCPC::MainWindow->new();
$wx->MainLoop;

package QCPC::MainWindow;
use strict;
use base qw(Wx::App);

sub OnInit {
	my $self  = shift;
	my $frame =
	  QCPC::Frame->new( undef, -1, "QCPC Application", [ 1, 1 ], [ 400, 400 ] );

	$self->SetTopWindow($frame);
	$frame->Show(1);
}
1;

package QCPC::Frame;
use strict;
use File::Find;
use Math::Complex;
use File::Basename;
use Excel::Writer::XLSX;
use Excel::Writer::XLSX::Utility;
use List::Util qw(max min);
use Wx::Event qw(EVT_BUTTON EVT_COMMAND);

use base qw(Wx::Frame);

my @control_list;
my @desired_list;

my @gprs;
my @graphs;    # holds all of the various graphs created for the excel file for
               # output at the end of the run
my %gprs_stats_cache
  ;            # cache the calculated means and stddev for each of the gpr files
my %peptide_row;    # holds the rows for peptides that are output
my ( $row, $col ) = ( 0, 0 );

my @mean;
my ( $datasheet, $graph );
my @peptides;

=head2 new

Initializes the frame and sets up the various buttons and events.

=cut

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);    # call the superclass' constructor
	     # Then define a Panel to put the button on
	my $panel = Wx::Panel->new(
		$self,    # parent
		-1        # id
	);
	my ( $gpr_dir_button, $xls_button, $run_button ) = ( 1 .. 10 );
	$self->{default_columns} =
	  [ "name", "id", "f635 median", "f635 mean", "b635 median", "b635 mean" ];

	$self->{list} = Wx::ListBox->new(
		$panel, -1,
		[ 0,   180 ],
		[ 240, 100 ],
		[], &Wx::wxLB_EXTENDED
	);
	@{ $self->{filter} } = (
		Wx::RadioButton->new(
			$panel, -1,
			"Mean", [ 250, 60 ],
			&Wx::wxDefaultSize, &Wx::wxRB_GROUP
		),

		Wx::RadioButton->new(
			$panel, -1, "Median", [ 250, 80 ],
			&Wx::wxDefaultSize
		)
	);

	$self->{gpr} = Wx::Button->new(
		$panel,             # parent
		$gpr_dir_button,    # ButtonID
		"GPR Folder",       # label
		[ 0, 300 ]          # position
	);
	EVT_BUTTON(
		$self,              # Object to bind to
		$gpr_dir_button,    # ButtonID
		\&GPRClicked        # Subroutine to execute
	);
	$self->{xls} = Wx::Button->new(
		$panel,             # parent
		$xls_button,        # ButtonID
		"XLS File",         # label
		[ 80, 300 ]         # position
	);
	EVT_BUTTON(
		$self,              # Object to bind to
		$xls_button,        # ButtonID
		\&XLSClicked        # Subroutine to execute
	);
	$self->{run} = Wx::Button->new(
		$panel,             # parent
		$run_button,        # ButtonID
		"Run Analysis",     # label
		[ 160, 300 ]        # position
	);
	EVT_BUTTON(
		$self,              # Object to bind to
		$run_button,        # ButtonID
		\&start_thread      # Subroutine to execute
	);

	Wx::StaticText->new(
		$panel,             # parent
		1,                  # id
		"Controls",         # label
		[ 0, 3 ]            # position
	);

	$self->{controls} = Wx::TextCtrl->new(
		$panel, -1,
		"fiducial, empty, blank, negative, positive, landing_lights",
		[ 80,  0 ],
		[ 160, 20 ],
	);

	Wx::StaticText->new(
		$panel,              # parent
		1,                   # id
		"Columns to Use",    # label
		[ 0, 60 ]            # position
	);

	$self->{columns} = Wx::ListBox->new(
		$panel, -1,
		[ 80,  60 ],
		[ 160, 100 ],
		[], &Wx::wxLB_EXTENDED
	);
	$self->{columns}->Set( $self->{default_columns} );
	foreach ( 0 .. scalar @{ $self->{default_columns} } ) {
		$self->{columns}->SetSelection($_);
	}
	EVT_COMMAND( $self, -1, $DONE_EVENT, \&done );
	return $self;
}

sub done {
	my ( $self, $event ) = @_;
	print $event->GetData;
	$self->{run}->Enable;
	foreach ( threads->list() ) {
		$_->join();
	}
	return;
}

sub start_thread {
	my $self = shift;
	$self->{run}->Disable;

	my @control_list = split( /\s?+,\s?+/, $self->{controls}->GetValue );
	my @desired_list = $self->{columns}->GetSelections();

	foreach ( 0 .. $#desired_list ) {
		$desired_list[$_] = $self->{columns}->GetString( $desired_list[$_] );
	}

	my @files;

	foreach ( $self->{list}->GetSelections() ) {
		push @files, $self->{list}->GetString($_);
	}

	my $filter = "median";
	foreach my $rb ( @{ $self->{filter} } ) {
		if ( $rb->GetValue() ) {
			$filter = $rb->GetLabel();
		}
	}

	threads->create(
		{ 'void' => 1 },
		\&RunClicked,
		{
			-window       => $self,
			-dir          => $self->{dir},
			-out          => $self->{xls},
			-control_list => join( ",", @control_list ),
			-desired_list => join( ",", @desired_list ),
			-filter       => $filter,
			-files        => \@files,
		}
	);
	return;
}

=head1 C<file_peptide_stats>

file_peptide_stats uses the cached gpr data held in @gprs to calculate the
mean, standard deviation and cv of each array for the non-controls.

	file_peptide_stats()
	
=cut

sub file_peptide_stats {
	my ($self) = @_;
	foreach my $gpr (@gprs) {
		my @data = ( $gpr->{"file"}, "Signal" );
		foreach my $signal (@mean) {
			my %data;
			my @signals;
			my $mean;
			my $stddev;
			foreach my $key ( keys %{ $gpr->{"peptides"} } ) {
				$mean += $gpr->{"peptides"}->{$key}->{$signal};
				push @signals, $gpr->{"peptides"}->{$key}->{$signal};
			}
			$mean /= scalar( keys %{ $gpr->{"peptides"} } );
			push @data, "$mean";

			foreach my $key ( keys %{ $gpr->{"peptides"} } ) {
				$stddev += ( $gpr->{"peptides"}->{$key}->{$signal} - $mean )**2;
			}
			$stddev = sqrt( $stddev / scalar( keys %{ $gpr->{"peptides"} } ) );
			push @data, "$stddev";
			my $cv = $stddev / $mean;
			push @data, "$cv";

			# min and max of the peptides
			my ($min) = sort { $a <=> $b } @signals;
			my ($max) = sort { $b <=> $a } @signals;
			push @data, ( "$min", "$max" );

			$data{"mean"}                                       = $mean;
			$data{"stddev"}                                     = $stddev;
			$gprs_stats_cache{ $gpr->{"file"} . "-" . $signal } = \%data;
		}
		$self->{worksheet}->write( $row, $col, \@data );
		$row++;
	}
}

=head1 C<file_control_stats>
file_control_stats prints out the mean, standard deviation and cv for the 
different controls found in the gpr files

	file_control_stats()	

=cut

sub file_control_stats {
	my ($self) = @_;
	foreach my $gpr (@gprs) {
		foreach my $control ( keys %{ $gpr->{"controls"} } ) {
			my @data = ( $gpr->{"file"}, "$control" );
			foreach my $signal (@mean) {
				my $mean;
				my $stddev;
				foreach my $key ( @{ $gpr->{"controls"}->{$control} } ) {
					$mean += $key->{$signal};
				}
				$mean /= scalar( @{ $gpr->{"controls"}->{$control} } );
				push @data, "$mean";

				foreach my $key ( @{ $gpr->{"controls"}->{$control} } ) {
					$stddev += ( $key->{$signal} - $mean )**2;
				}
				$stddev =
				  sqrt(
					$stddev / scalar( @{ $gpr->{"controls"}->{$control} } ) );
				push @data, "$stddev";
				my $cv = $stddev / $mean;
				push @data, "$cv";

				# min and max of the controls
				my ($min) =
				  sort { $a->{$signal} <=> $b->{$signal} }
				  @{ $gpr->{"controls"}->{$control} };
				my ($max) =
				  sort { $b->{$signal} <=> $a->{$signal} }
				  @{ $gpr->{"controls"}->{$control} };
				push @data, ( $min->{$signal}, $max->{$signal} );
			}
			$self->{worksheet}->write( $row, $col, \@data );
			$row++;
		}
	}
}

=head1 C<file_total_stats>

file_total_stats uses the cached gpr data held in @gprs to calculate the total
inter-array mean, standard deviation and cv for all the peptides and all the 
controls separately.

	file_total_stats()
	
=cut

sub file_total_stats {
	my ($worksheet) = @_;
	my @controls;    # the controls that were actually found for the first file
	                 #(and so for each file after I hope)
	$col = 1;
	foreach my $signal (@mean) {
		$row = 1;
		foreach my $control (@control_list) {
			my $mean;
			my $stddev;
			my $count;
			next
			  if ( !defined( $gprs[0]->{"controls"}->{$control} ) );
			push @controls, $control;

			foreach my $gpr (@gprs) {
				foreach my $key ( @{ $gpr->{"controls"}->{$control} } ) {
					$mean += $key->{$signal};
					$count++;
				}
			}
			next if ( !$count );
			$mean /= $count;

			foreach my $gpr (@gprs) {
				foreach my $key ( @{ $gpr->{"controls"}->{$control} } ) {
					$stddev += ( $key->{$signal} - $mean )**2;
				}
				$stddev = sqrt( $stddev / $count );
			}
			my $cv = $stddev / $mean;
			$worksheet->write( $row++, $col, [ "$mean", "$stddev", "$cv" ] );
		}

		# found the mean for the various control types. Now do the same for all
		# the peptides
		my ( $mean, $stddev, $cv, $count );

		foreach my $gpr (@gprs) {
			foreach my $key ( keys %{ $gpr->{"peptides"} } ) {
				$mean += $gpr->{"peptides"}->{$key}->{$signal};
				$count++;
			}
		}
		next if ( !$count );
		$mean /= $count;

		foreach my $gpr (@gprs) {
			foreach my $key ( keys %{ $gpr->{"peptides"} } ) {
				$stddev += ( $gpr->{"peptides"}->{$key}->{$signal} - $mean )**2;
			}
			$stddev = sqrt( $stddev / $count );
		}
		$cv = $stddev / $mean;
		$worksheet->write( $row++, $col, [ "$mean", "$stddev", "$cv" ] );
		$col += 3;
	}
	$col = 0;
	$row = 1;
	foreach ( unique(@controls) ) {
		$worksheet->write( $row++, $col, $_ );
	}
	$worksheet->write( $row, $col, "Signal" );
}

=head1 C<col_to_ref>

Converts A1 excel notation to $A$1

	col_to_ref($col)
	
=cut

sub col_to_ref {
	my ($col) = @_;
	if ( $col =~ /([a-z]+)([\d]+)/i ) { $col = '$' . $1 . '$' . $2; }
	return $col;
}

=head2 log_base

Converts a number to a log base N result.

	log_base($base, $number)

=cut

sub log_base {
	my ( $base, $value ) = @_;
	if ( $value > 0 && $base > 0 ) {
		return log($value) / log($base);
	}
	else { return 0; }
}

=head2 GPRClicked

Function that is engaged when the GPR Folder button is clicked. Processes the
choice of directory made by the end user.

=cut

sub GPRClicked {
	my ( $self, $event ) = @_;
	$self->{dir} = Wx::DirSelector( "Select GPR Directory", $self->{dir}, "" );
	if ( -e $self->{dir} && -d $self->{dir} ) {
		opendir my $dh, $self->{dir}
		  || die "can't opendir " . $self->{dir} . " $!";
		my @files = grep { /\.gpr$/ && -f $self->{dir} . "/$_" } readdir($dh);
		$self->{list}->Set( \@files );
		open my $fh, $self->{dir} . "/" . $files[0];
		while ( my $line = <$fh> ) {
			if ( $line =~ /^"?block"?/i ) {
				chomp($line);
				$line =~ s/["']//g;

				my @current_selections = $self->{columns}->GetSelections();
				foreach ( 0 .. $#current_selections ) {
					$current_selections[$_] =
					  $self->{columns}->GetString( $current_selections[$_] );
				}

				#split the line on tabs for mapping
				my @temp = split( /\t/, lc($line) );
				$self->{columns}->Set( \@temp );
				foreach ( 0 .. $#temp ) {
					if ( inlist( $temp[$_], @current_selections ) ) {
						$self->{columns}->SetSelection($_);
					}
				}
				last;
			}
		}

	}
}

=head2 XLSClicked

Function that is engaged when the XLS File button is clicked. Processes the 
choice of file made by the end user. This function changes the extension of 
the file to be .xlsx whether the user selected an xlsx file or not.

=cut

sub XLSClicked {
	my ( $self, $event ) = @_;
	( $self->{xls} ) = Wx::FileSelector("Select XLSX File for writing");
	if ( $self->{xls} !~ /\.xlsx$/i ) {
		$self->{xls} =~ s/\.[a-z]{2,4}$//i;
		$self->{xls} .= '.xlsx';
	}
}

=head2 RunClicked

Function that is engaged when the Run button is clicked. Reads in the selected 
GPR files for processing.

=cut

sub RunClicked {
	print scalar(@_) . "\n";
	my $parameters = shift;

	my ( @control_list, @desired_list, @gprs, @graphs, @peptides );

	%gprs_stats_cache = %peptide_row = {};
	$row              = 0;
	$col              = 0;

	if ( $parameters->{-dir} eq "" ) {
		Wx::MessageBox( "No Directory was Selected", "ERROR!!!", "", -1 );
		my $threvent = new Wx::PlThreadEvent( -1, $DONE_EVENT, 0 );
		Wx::PostEvent( $parameters->{-window}, $threvent );
		return;
	}
	if ( ref( $parameters->{-out} ) ne "" || $parameters->{-out} eq "" ) {
		Wx::MessageBox( "No Excel File was Selected", "ERROR!!!", "", -1 );
		my $threvent = new Wx::PlThreadEvent( -1, $DONE_EVENT, 0 );
		Wx::PostEvent( $parameters->{-window}, $threvent );
		return;
	}
	@control_list = split( /,/, $parameters->{-control_list} );
	@desired_list = split( /,/, $parameters->{-desired_list} );

# defalut to median so that the user doesn't have to select a value from the radio selections
	my $filter = $parameters->{-filter};

# find the headers that match the pattern of fXXX or bXXX to find the light frequencies in the GPR files
	my $search = '^[fb]\d{1,3}.*' . lc($filter) . '$';

	@mean = grep( /$search/, @desired_list );

 # create a new file. This will overwrite the selected XLSX file if one existed.
	my $EXCEL = Excel::Writer::XLSX->new( $parameters->{-out} );

	foreach ( 0 .. $#{ $parameters->{-files} } ) {
		$gprs[@gprs] =
		  Microarray::gpr->new( -file => $parameters->{-dir} . "/"
			  . ${ $parameters->{-files} }[$_] );
	}

	my $current_worksheet = $EXCEL->add_worksheet('Files');
	my $graphsheet        = $EXCEL->add_worksheet('Graphs');

	foreach my $gpr (@gprs) {
		$current_worksheet->write( $row, $col++, $gpr->get_filename() );
		foreach (@control_list) {
			$current_worksheet->write( $row, $col,
				[ $_, $gpr->get_row_count($_) ] );
			$col += 2;
		}
		$current_worksheet->write( $row, $col,
			[ "peptides", $gpr->get_keys() ] );
		$row++;
		$col = 0;
	}

	$current_worksheet = $EXCEL->add_worksheet('File Statistics');

	my @headers = ( "File", "Control" );
	foreach (@mean) {
		push @headers, ( "$_", "$_ stddev", "$_ cv", "Min", "Max" );
	}
	$current_worksheet->write( 0, 0, \@headers );
	$row = 1;
	$col = 0;

	foreach my $gpr (@gprs) {
		my @data = ( $gpr->get_filename(), "Signal" );
		foreach my $signal (@mean) {
			my %data;
			my @signals;
			my $mean;
			my $stddev;
			foreach my $key ( $gpr->get_keys() ) {
				$mean += $gpr->get_datum($key)->{$signal};
				push @signals, $gpr->get_datum($key)->{$signal};
			}
			$mean /= scalar( $gpr->get_keys() );
			push @data, $mean;

			foreach my $key ( $gpr->get_keys() ) {
				$stddev += ( $gpr->get_datum($key)->{$signal} - $mean )**2;
			}
			$stddev = sqrt( $stddev / scalar( $gpr->get_keys() ) );
			push @data, $stddev;
			my $cv = $stddev / $mean;
			push @data, $cv;

			# min and max of the peptides
			my ($min) = sort { $a <=> $b } @signals;
			my ($max) = sort { $b <=> $a } @signals;
			push @data, ( $min, $max );

			$data{"mean"}                                             = $mean;
			$data{"stddev"}                                           = $stddev;
			$gprs_stats_cache{ $gpr->get_filename() . "-" . $signal } = \%data;
		}
		$current_worksheet->write( $row, $col, \@data );
		$row++;
	}

	foreach my $gpr (@gprs) {
		foreach my $control (@control_list) {
			my @data = ( $gpr->get_filename(), "$control" );
			foreach my $signal (@mean) {
				my $mean;
				my $stddev;
				foreach my $key ( $gpr->get_row_data($control) ) {
					$mean += $key->{$signal};
				}
				$mean /= $gpr->get_row_count($control)
				  if ( $gpr->get_row_count($control) > 0 );
				push @data, $mean;

				foreach my $key ( $gpr->get_row_data($control) ) {
					$stddev += ( $key->{$signal} - $mean )**2;
				}
				$stddev = sqrt( $stddev / $gpr->get_row_count($control) )
				  if ( $gpr->get_row_count($control) > 0 );
				push @data, $stddev;
				my $cv = $stddev / $mean;
				push @data, $cv;

				# min and max of the controls
				my ($min) =
				  sort { $a->{$signal} <=> $b->{$signal} }
				  $gpr->get_row_data($control);
				my ($max) =
				  sort { $b->{$signal} <=> $a->{$signal} }
				  $gpr->get_row_data($control);
				push @data, ( $min->{$signal}, $max->{$signal} );
			}
			$current_worksheet->write( $row, $col, \@data );
			$row++;
		}
	}

	$current_worksheet = $EXCEL->add_worksheet('Array Data');
	$current_worksheet->hide();
	$row = 1;
	$col = 0;

	my $count = 1;
	my @peptides;
	foreach my $gpr (@gprs) {
		push @peptides, $gpr->get_keys();
	}

	@peptides = unique(@peptides);
	for ( my $i = 0 ;
		$i < @peptides ; $i += max( 1, int( @peptides / 20000 ) ) )
	{
		$current_worksheet->write( $count, $col, $peptides[$i] );
		$peptide_row{ $peptides[$i] } = $count++;
	}
	$col = 1;

	# Write out the array data to an excel sheet then create the relation graphs
	# for each pairs of data written out. Think I'll merge these into each other
	# for simplicity of the creation of the graphs.
	my ($mean) = @mean;
	my @keys = keys %peptide_row;
	foreach my $gpr (@gprs) {
		$current_worksheet->write( 0, $col, $gpr->{'file'} );
		foreach my $key (@keys) {
			if (   defined( $gpr->get_datum($key) )
				&& defined( $peptide_row{$key} ) )
			{
				$current_worksheet->write( $peptide_row{$key}, $col,
					log_base( 10, $gpr->get_datum($key)->{$mean} ) );
			}
		}
		$col++;
	}
	foreach my $i ( 1 .. $col - 2 ) {
		foreach my $j ( $i + 1 .. $col - 1 ) {
			my $graph = $EXCEL->add_chart( type => 'scatter', embedded => 1 );
			$graph->set_title( name => $gprs[ $i - 1 ]->get_filename() . ' vs '
				  . $gprs[ $j - 1 ]->get_filename() );
			$graph->add_series(
				categories => '='
				  . $current_worksheet->get_name() . '!'
				  . col_to_ref( xl_rowcol_to_cell( 1, $i ) ) . ':'
				  . col_to_ref( xl_rowcol_to_cell( scalar @keys, $i ) ),
				values => '='
				  . $current_worksheet->get_name() . '!'
				  . col_to_ref( xl_rowcol_to_cell( 1, $j ) ) . ':'
				  . col_to_ref( xl_rowcol_to_cell( scalar @keys, $j ) ),
			);
			$graph->set_x_axis(
				name => "log10 " . $gprs[ $i - 1 ]->get_filename() );
			$graph->set_y_axis(
				name => "log10 " . $gprs[ $j - 1 ]->get_filename() );
			$graph->set_legend( position => 'none' );
			push @graphs, $graph;
		}
	}

	$datasheet         = $EXCEL->add_worksheet('Log Ratio Data');
	$current_worksheet = $EXCEL->add_worksheet('File Log Ratios');
	$datasheet->hide();
	$row = $col = 0;

	my $graph = $EXCEL->add_chart(
		type     => 'column',
		embedded => 1
	);

	my $data_col = 0;
	my %ratio_buckets;    # gather up all the log2 ratio data into buckets
	foreach ( keys %peptide_row ) {
		$datasheet->write( $peptide_row{$_}, $data_col, $_ );
	}
	$data_col++;
	$row = $col = 0;
	($mean) = @mean;
	$current_worksheet->write( $row++, $col,
		[ "File 1", "File 2", "$_ Ratio", "$mean 95% CI" ] );
	foreach my $i ( 0 .. $#gprs - 1 ) {
		my $gpr1 = $gprs[$i];
		my @keys = $gpr1->get_keys();
		foreach my $j ( $i + 1 .. $#gprs ) {
			my @CI;    # confidence interval
			my $count = 0;
			my $array_mean;
			my $gpr2 = $gprs[$j];
			$datasheet->write( 0, $data_col,
				$gpr1->get_filename() . "/" . $gpr2->get_filename() );
			foreach my $key (@keys) {
				if (   defined( $gpr1->get_datum($key) )
					&& defined( $gpr2->get_datum($key) ) )
				{
					if (   $gpr1->get_datum($key)->{$mean} > 0
						&& $gpr2->get_datum($key)->{$mean} > 0 )
					{
						$count++;
						push @CI,
						  log_base( 2,
							$gpr1->get_datum($key)->{$mean} /
							  $gpr2->get_datum($key)->{$mean} );
						$ratio_buckets{ int( $CI[$#CI] * 10 ) }++;
						$CI[$#CI] = abs( $CI[$#CI] );
						$array_mean += $CI[$#CI];
						if ( defined( $peptide_row{$key} ) ) {
							$datasheet->write( $peptide_row{$key}, $data_col,
								$CI[$#CI] );
						}

					}
				}
			}
			if ( $count > 0 ) {
				@CI = sort @CI;
				$current_worksheet->write(
					$row++,
					$col,
					[
						$gpr1->get_filename(), $gpr2->get_filename(),
						$array_mean / $count,  2**$CI[ int( .95 * @CI ) ]
					]
				);
			}
			$data_col++;
		}
	}
	my ( $x_name, $y_name );
	$x_name = $y_name = '=' . $datasheet->get_name() . '!';
	$data_col
	  ++; # create an empty column between the file ratios and the overall bucket data
	$row = 0;

	$datasheet->write( $row++, $data_col, [ "Power", "Count" ] );
	$x_name .= col_to_ref( xl_rowcol_to_cell( $row, $data_col ) ) . ':';
	$y_name .= col_to_ref( xl_rowcol_to_cell( $row, $data_col + 1 ) ) . ':';
	foreach my $key ( sort { $a <=> $b } keys %ratio_buckets ) {
		$datasheet->write( $row++, $data_col,
			[ $key / 10, $ratio_buckets{$key} ] );
	}
	$x_name .= col_to_ref( xl_rowcol_to_cell( $row - 1, $data_col ) );
	$y_name .= col_to_ref( xl_rowcol_to_cell( $row - 1, $data_col + 1 ) );
	$graph->set_title( name => 'Log Ratio Buckets' );
	$graph->set_x_axis( name => 'Log2 Power' );
	$graph->set_y_axis( name => 'Count' );
	$graph->add_series(
		name       => 'Ratios',
		categories => $x_name,
		values     => $y_name,
	);
	push @graphs, $graph;

	my @controls;

	$current_worksheet = $EXCEL->add_worksheet('Across Array Stats');
	@headers           = ("Control");
	foreach (@mean) {
		push @headers, ( "$_", "$_ stddev", "$_ cv" );
	}
	$current_worksheet->write( 0, 0, \@headers );
	$col = 1;
	foreach my $signal (@mean) {
		$row = 1;
		foreach my $control (@control_list) {
			my $mean;
			my $stddev;
			my $count;
			next
			  if ( !defined( $gprs[0]->get_data($control) ) );
			push @controls, $control;

			foreach my $gpr (@gprs) {
				foreach my $key ( $gpr->get_row_data($control) ) {
					$mean += $key->{$signal};
					$count++;
				}
			}
			next if ( !$count );
			$mean /= $count;

			foreach my $gpr (@gprs) {
				foreach my $key ( $gpr->get_row_data($control) ) {
					$stddev += ( $key->{$signal} - $mean )**2;
				}
				$stddev = sqrt( $stddev / $count );
			}
			my $cv = $stddev / $mean;
			$current_worksheet->write( $row++, $col, [ "$mean", "$stddev", "$cv" ] );
		}

		# found the mean for the various control types. Now do the same for all
		# the peptides
		my ( $mean, $stddev, $cv, $count );

		foreach my $gpr (@gprs) {
			foreach my $key ( $gpr->get_keys() ) {
				$mean += $gpr->get_datum($key)->{$signal};
				$count++;
			}
		}
		next if ( !$count );
		$mean /= $count;

		foreach my $gpr (@gprs) {
			foreach my $key ( $gpr->get_keys() ) {
				$stddev += ( $gpr->get_datum($key)->{$signal} - $mean )**2;
			}
			$stddev = sqrt( $stddev / $count );
		}
		$cv = $stddev / $mean;
		$current_worksheet->write( $row++, $col, [ "$mean", "$stddev", "$cv" ] );
		$col += 3;
	}
	$col = 0;
	$row = 1;
	foreach ( unique(@controls) ) {
		$current_worksheet->write( $row++, $col, $_ );
	}
	$current_worksheet->write( $row, $col, "Signal" );

	$current_worksheet = $EXCEL->add_worksheet('Correlation');
	$col               = $row = 0;

	# Correlation calculations

	$current_worksheet->write( $row++, $col,
		[ "File 1", "File 2", "Correlation", "R-squared" ] );
	my ($mean) = @mean;

	#print $mean. "\n";
	foreach my $i ( 0 .. $#gprs - 1 ) {
		my $gpr1 = $gprs[$i];
		my @keys = keys %peptide_row;
		foreach my $j ( $i + 1 .. $#gprs ) {
			my $count = 0;
			my $r;
			my $gpr2 = $gprs[$j];
			foreach my $key (@peptides) {
				if (   defined( $gpr1->get_datum($key) )
					&& defined( $gpr2->get_datum($key) ) )
				{
					if (   $gpr1->get_datum($key)->{$mean} >= 0
						&& $gpr2->get_datum($key)->{$mean} >= 0 )
					{
						$count++;
						$r += (
							(
								$gpr1->get_datum($key)->{$mean} -
								  $gprs_stats_cache{ $gpr1->get_filename() . "-"
									  . $mean }->{"mean"}
							) / $gprs_stats_cache{ $gpr1->get_filename() . "-"
								  . $mean }->{"stddev"}
						  ) * (
							(
								$gpr2->get_datum($key)->{$mean} -
								  $gprs_stats_cache{ $gpr2->get_filename() . "-"
									  . $mean }->{"mean"}
							) / $gprs_stats_cache{ $gpr2->get_filename() . "-"
								  . $mean }->{"stddev"}
						  );
					}
				}
			}
			$r /= $count if ( $count > 0 );
			$current_worksheet->write(
				$row++,
				$col,
				[
					$gpr1->get_filename(), $gpr2->get_filename(), $r, $r**2,
					$mean
				]
			);
		}
	}

	$current_worksheet = $EXCEL->add_worksheet('Slide Density Data');
	$current_worksheet->hide();
	my $max = 0;   # what is the max array size so that the index can be created
	my $col = 1;
	foreach my $i ( 0 .. $#gprs ) {
		my $gpr = $gprs[$i];
		foreach my $j ( 0 .. $#mean ) {
			my $mean = $mean[$j];
			$current_worksheet->write( 0, $col,
				$gpr->get_filename() . " " . $mean );
			my @density;
			foreach my $key ( $gpr->get_keys() ) {
				$density[
				  int( 10 * log_base( 10, $gpr->get_datum($key)->{$mean} ) ) ]
				  ++;
			}
			$current_worksheet->write( 1, $col, [ \@density ] );
			$max = max( $max, scalar $#density );
			my $graph = $EXCEL->add_chart( type => 'column', embedded => 1 );
			my ( $x_name, $y_name );
			$x_name = $y_name = '=' . $current_worksheet->get_name() . '!';
			$x_name .=
			    col_to_ref( xl_rowcol_to_cell( 1, 0 ) ) . ':'
			  . col_to_ref( xl_rowcol_to_cell( $max, 0 ) );
			$y_name .=
			    col_to_ref( xl_rowcol_to_cell( 1, $col ) ) . ':'
			  . col_to_ref( xl_rowcol_to_cell( $max, $col ) );

			$graph->set_title( name => $gpr->get_filename() . " " . $mean );
			$graph->set_x_axis( name => 'Log10 Signal' );
			$graph->set_y_axis( name => 'Count' );
			$graph->add_series(
				name       => $gpr->get_filename() . " " . $mean,
				categories => $x_name,
				values     => $y_name,
			);
			push @graphs, $graph;
			$col++;
		}
	}
	my $i = 2;
	($mean) = @mean;
	foreach my $gpr (@gprs) {
		foreach my $control ( keys %{ $gpr->{"controls"} } ) {
			my @density;
			$current_worksheet->write( 0, $col,
				$gpr->{"file"} . " " . $control );
			foreach ( @{ $gpr->{"controls"}->{$control} } ) {
				$density[ int( 10 * log_base( 10, $_->{$mean} ) ) ]++;
			}
			$max = max( $max, scalar $#density );
			$current_worksheet->write( 1, $col, [ \@density ] );
			my $graph = $EXCEL->add_chart(
				name     => "A$i",
				type     => 'column',
				embedded => 1
			);
			my ( $x_name, $y_name );
			$x_name = $y_name = '=' . $current_worksheet->get_name() . '!';
			$x_name .=
			    col_to_ref( xl_rowcol_to_cell( 1, 0 ) ) . ':'
			  . col_to_ref( xl_rowcol_to_cell( $max, 0 ) );
			$y_name .=
			    col_to_ref( xl_rowcol_to_cell( 1, $col ) ) . ':'
			  . col_to_ref( xl_rowcol_to_cell( $max, $col ) );

			$graph->set_title( name => $gpr->{"file"} . " " . $control );
			$graph->set_x_axis( name => 'Log10 Signal' );
			$graph->set_y_axis( name => 'Count' );
			$graph->add_series(
				name       => $gpr->{"file"} . " " . $control,
				categories => $x_name,
				values     => $y_name,
			);
			push @graphs, $graph;
			$col++;
		}
	}
	foreach ( 0 .. $max ) {
		$current_worksheet->write( $_ + 1, 0, $_ / 10 );
	}
	foreach ( 0 .. $#graphs ) {
		$graphsheet->insert_chart(
			xl_rowcol_to_cell( 20 * int( $_ / 5 ), 9 * ( $_ % 5 ) ),
			$graphs[$_] );
	}

	my $result = "Testing";

	my $threvent = new Wx::PlThreadEvent( -1, $DONE_EVENT, $result );
	print ref($threvent);
	Wx::PostEvent( $parameters->{-window}, $threvent );
}

=head1 C<inlist>

inlist searches through a list of items to see if there is a match with the
desired item.  Handles dealing with an array of strings or an array of sequence
objects from BioPerl.  This function could probably be made more robust, but
nothing has forced it to be changed any further.

	inlist($item, @find_in_array)
	
=cut

sub inlist {
	my $value = shift;
	$value =~ s/(['"\\\[\]])/\\$1/g;
	local ($_);
	if ( ref( $_[0] ) eq 'HASH' ) {
		$_ = '~';
		foreach my $seq (@_) {
			$_ .= $seq->seq . '~';
		}
	}
	elsif ( !( ref( $_[0] ) ) ) {
		$_ = '~' . join( '~', @_ ) . '~';
	}
	return (0) unless /^(.*?~$value)~/i;
	my $chunk = $1;
	$chunk =~ tr/~//;
}

=head1 C<average>
average returns the mean value of an array of values. They do not need to be 
presorted before calling.

	average(\@values)	

=cut

sub average {
	my ($array_ref) = @_;
	my $sum;
	my $count = scalar @$array_ref;
	foreach (@$array_ref) { $sum += $_; }
	return $sum / $count;
}

=head1 C<median>
median returns the median value of an array of values. They do not need to be 
presorted before calling.

	median(\@values)	

=cut

sub median {
	@_ == 1 or die('Sub usage: $median = median(\@array);');
	my ($array_ref) = @_;
	my $count = scalar @$array_ref;

	# Sort a COPY of the array, leaving the original untouched
	my @array = sort { $a <=> $b } @$array_ref;
	if ( $count % 2 ) {
		return $array[ int( $count / 2 ) ];
	}
	else {
		return ( $array[ $count / 2 ] + $array[ $count / 2 - 1 ] ) / 2;
	}
}

=head1 C<unique>

Takes in a list of items and returns an array of just the unique items contained in it.
	unique(@items)

=cut

sub unique {
	my @list  = @_;
	my %seen  = ();
	my @uniqu = grep { !$seen{$_}++ } @list;
	return @uniqu;
}

=head1 C<files>

Files reads through the passed filename and sets up the various stages for 
comparing this GPR to the others

	files($filepath)	

=cut

sub files {
	$_ = shift @_;

	#print "$_\n";
	return if ( $_ !~ /\.gpr$/ );

	my %gpr;

	my %headers;

	my %peptides
	  ;    # this should hold the data for the various peptides on an array
	my %controls
	  ;    # this should hold the data for the various controls on an array

	open my $fh, $_ || return;
	$gpr{'file'} = fileparse( $_, '.gpr' );

	# need to strip the header rows off the GPR file
	# probably not important to keep them around

	while ( my $line = <$fh> ) {
		if ( $line =~ /^"?block"?/i ) {
			$line =~ s/["']//g;

			#split the line on tabs for mapping
			my @temp = split( /\t/, $line );
			foreach ( 0 .. $#temp ) {
				$headers{ lc( $temp[$_] ) } = $_;
			}
			last;
		}
	}

 # at this point we've read in all the various header rows and setup the column
 # header data now we need to parse through the actual data columns and pull out
 # the data that we need

	while ( my $line = <$fh> ) {
		my %datapoint;
		chomp $line;
		$line =~ s/["']//g;
		my @line = split( /\t/, $line );

		foreach (@desired_list) {
			$datapoint{$_} = $line[ $headers{$_} ];
		}

		# is this a control element or a data point. each is handled slightly
		# differently.
		if ( inlist( $line[ $headers{'name'} ], @control_list ) ) {
			push @{ $controls{ lc( $line[ $headers{'name'} ] ) } }, \%datapoint;
		}

	  # else this is a piece of data. Need to temporarily store these to do
	  # data manipulation on a single array of data before comparing data across
	  # the various gpr files.
		else {
			push @{ $peptides{ $line[ $headers{'name'} ] } }, \%datapoint;
		}
	}

	my %temp;

	foreach ( keys %peptides ) {
		if ( @{ $peptides{$_} } <= 1 ) {
			$temp{$_} = ${ $peptides{$_} }[0];
		}
		else {
			my %datapoint;
			foreach my $element (@desired_list) {
				if ( $element eq "name" ) {
					$datapoint{$element} = $_;
					next;
				}
				if ( $element eq "id" ) {
					$datapoint{$element} = ${ $peptides{$_} }[0]->{$element};
					next;
				}
				my @data
				  ; # holds the values that are going to be either averaged or median
				foreach my $data ( @{ $peptides{$_} } ) {
					push @data, $data->{$element};
				}
				if ( $element =~ /median/i ) {
					$datapoint{$element} = median( \@data );
				}
				elsif ( $element =~ /mean/i ) {
					$datapoint{$element} = average( \@data );
				}
			}
			$temp{$_} = \%datapoint;
		}

	}
	%peptides        = %temp;
	$gpr{"controls"} = \%controls;
	$gpr{"peptides"} = \%peptides;
	return \%gpr;
}
1;
