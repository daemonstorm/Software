package Microarray::gpr;
use strict;
use File::Basename;

sub new {
	my $class = shift;
	my $self  = {};
	if ( $_[0] eq "-file" ) {
		$self->{_file} = $_[1];
	}
	$self->{_data} = {};
	$self->{_rows} = [];
	bless $self, $class;

	if ( defined( $self->{_file} ) && length( $self->{_file} ) > 0 ) {
		$self->_parse_file();
	}

	return $self;
}

sub _parse_file {
	my $self = shift;

	my %peptides
	  ;    # this should hold the data for the various peptides on an array

	open my $fh, $self->{_file} || return;

	# need to strip the header rows off the GPR file
	# probably not important to keep them around

	while ( my $line = <$fh> ) {
		if ( $line =~ /^"?block"?/i ) {
			$line =~ s/["']//g;

			#split the line on tabs for mapping
			my @temp = split( /\t/, $line );
			foreach ( 0 .. $#temp ) {
				$self->{_headers}->{ lc( $temp[$_] ) } = $_;
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

		foreach ( keys %{ $self->{_headers} } ) {
			$datapoint{$_} = $line[ $self->{_headers}->{$_} ];
		}

		if ( $datapoint{'name'} =~ /^[\s]?+$/ ) {
			$datapoint{'name'} = $datapoint{'id'};
		}
		if ( $datapoint{'id'} =~ /^[\s]?+$/ ) {
			$datapoint{'id'} = $datapoint{'name'};
		}
		if (   $datapoint{'name'} =~ /^[\s]?+$/
			&& $datapoint{'id'} =~ /^[\s]?+$/ )
		{
			$datapoint{'name'} = 'empty';
			$datapoint{'id'}   = 'empty';
		}

		push @{ $self->{_rows} }, \%datapoint;
		push @{ $peptides{ $datapoint{'name'} } }, \%datapoint;
	}

	my %temp;

	foreach ( keys %peptides ) {
		if ( @{ $peptides{$_} } <= 1 ) {
			$temp{$_} = ${ $peptides{$_} }[0];
		}
		else {
			my %datapoint;
			foreach my $element ( keys %{ $self->{_headers} } ) {

	   # force the name of the element to be the same as the key used previously
				if ( $element eq "name" ) {
					$datapoint{$element} = $_;
					next;
				}

# for all non-numeric fields, just accept the result from the first record and move on
				if (   ${ $peptides{$_} }[0]->{$element} == 0
					&& ${ $peptides{$_} }[0]->{$element} ne '0' )
				{
					$datapoint{$element} = ${ $peptides{$_} }[0]->{$element};
					next;
				}

   # for all other data, which should be numeric, find the average of the result
				my @data;
				foreach my $data ( @{ $peptides{$_} } ) {
					push @data, $data->{$element};
				}

				$datapoint{$element} = $self->_average( \@data );
			}
			$temp{$_} = \%datapoint;
		}
	}
	$self->{_data} = \%temp;
	close $fh;
}

=head1 C<get_datum>
returns the hash reference for the desired row of data from the GPR file. By default the used column is the Name field for collecting unique items.
	
	hash reference = get_datum(key)
	
=cut

sub get_datum {
	my $self = shift;
	my $key  = shift;
	if ( defined( $self->{_data}->{$key} ) ) {
		return $self->{_data}->{$key};
	}
	else { return undef; }
}

=head1 C<get_filename>
returns the filename that was parsed by this object.

	get_filename()	

=cut

sub get_filename {
	my $self = shift;
	my $name = fileparse( $self->{_file}, '.gpr' );
	return $name;
}

=head1 C<get_keys>
returns an array of keys from the Name column.

	@keys = get_keys()
	
=cut

sub get_keys {
	my $self = shift;
	return keys( %{ $self->{_data} } );
}

=head1 C<average>
average returns the mean value of an array of values. They do not need to be 
presorted before calling.

	average(\@values)	

=cut

sub _average {
	my $self = shift;
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

sub _median {
	my $self = shift;
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

=head1 C<get_row_count>
get_row_count returns the number of rows in the GPR that match the 'name' field requested

	get_row_count('string');

=cut

sub get_row_count {
	my $self    = shift;
	my $key     = shift;
	my $results = grep { $_->{'name'} eq $key } @{ $self->{_rows} };
	return $results;
}

=head1 C<get_row_data>
get_row_data returns the rows in the GPR that match the 'name' field requested

	get_row_data('string');

=cut

sub get_row_data {
	my $self    = shift;
	my $key     = shift;
	my @results = grep { $_->{'name'} eq $key } @{ $self->{_rows} };
	return @results;
}

=head1 C<get_headers>
get_headers returns the headers found in the given GPR file

	get_headers('string');

=cut

sub get_headers {
	my $self = shift;
	return keys %{ $self->{_headers} };
}
1;
