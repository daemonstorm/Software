#!/bin/env perl
use strict;
use threads;
use Wx;

my @dice   = qw/Ability Proficiency Boost Difficulty Challenge Setback Force/;
my @colors = qw/0x54b948 0xffe800 0xa4d6f4 0x53247f 0xe31836 0x231f20 0xffffff/;

my $wx = QCPC::MainWindow->new();
$wx->MainLoop;

package QCPC::MainWindow;
use strict;
use base qw(Wx::App);

sub OnInit {
	my $self  = shift;
	my $frame =
	  QCPC::Frame->new( undef, -1, "Star Wars Dice Roller", [ 1, 1 ], [ 400, 400 ] );

	$self->SetTopWindow($frame);
	$frame->Show(1);
}
1;

package QCPC::Frame;
use strict;
use Wx::Event qw(EVT_BUTTON EVT_COMMAND);

use base qw(Wx::Frame);

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

	my ( $x, $y ) = ( 0, 10 );
	my ($run_button) = ( 1 .. 10 );

	$self->{results} = Wx::TextCtrl->new(
		$panel, -1,
		"Result of the roll here",
		[ 80,  200 ],
		[ 160, 20 ],
	);

	@{ $self->{filter} } = (
		Wx::RadioButton->new(
			$panel, -1,
			"Autoreduce results", [ 250, 60 ],
			&Wx::wxDefaultSize, &Wx::wxRB_GROUP
		),

		Wx::RadioButton->new(
			$panel, -1,
			"Don't Autoreduce results", [ 250, 80 ],
			&Wx::wxDefaultSize
		)
	);

	$self->{run} = Wx::Button->new(
		$panel,         # parent
		$run_button,    # ButtonID
		"Roll Dice",    # label
		[ 250, 100 ]    # position
	);
	EVT_BUTTON(
		$self,          # Object to bind to
		$run_button,    # ButtonID
		\&roll_dice     # Subroutine to execute
	);

	for ( my $i = 0 ; $i < @dice ; $i++ ) {
		my $label = Wx::StaticText->new(
			$panel,       # parent
			1,            # id
			$dice[$i],    # label
			[ $x, $y + 20 * $i ],    # position
			[ 60, 20 ],
			&Wx::wxALIGN_CENTRE | &Wx::wxST_NO_AUTORESIZE,

		);
		$label->SetBackgroundColour( $self->make_color( $colors[$i] ) );

		$self->{ $dice[$i] } = Wx::TextCtrl->new(
			$panel, -1, "0",
			[ $x + 80, $y + 20 * $i ],
			[ 40,      20 ],
		);
	}
	
	Wx::StaticText->new(
			$panel,       # parent
			1,            # id
			"Minor notes:\na = Advantage\ns = Success\nT = Triumph\n",    # label
			[ 80, 220 ],    # position
			[ 80, 80 ],
			&Wx::wxST_NO_AUTORESIZE,
	);
	Wx::StaticText->new(
			$panel,       # parent
			1,            # id
			"t = Threat\nf = Failure\nD = Despair",    # label
			[ 160, 232 ],    # position
			[ 80, 80 ],
			&Wx::wxST_NO_AUTORESIZE,
	);
	Wx::StaticText->new(
			$panel,       # parent
			1,            # id
			"The success of the Triumph and the failure of the Despair is already accounted for. If the final result shows a Triumph, but not a Success, then the Triumph's Success was cancelled by a Failure\nSame thing for the Despair and its Failure",    # label
			[ 80, 300 ],    # position
			[ 240, 80 ],
			&Wx::wxST_NO_AUTORESIZE,
	);
	return $self;
}

sub make_color {
	my ( $self, $color ) = @_;
	if ( $color =~ /^0x/ ) {
		$color = hex($color);
	}
	return undef unless $color;
	return undef if $color =~ /^no$/i;
	my $b = $color % 256;
	$color = ( $color - $color % 256 ) / 256;
	my $g = $color % 256;
	$color = ( $color - $color % 256 ) / 256;
	my $r = $color % 256;
	return new Wx::Colour( $r, $g, $b );
}

sub roll_dice {
	my $self = shift;
	my @result;

#s = success, f=failure, t=threat, a=advantage, T=triumph, D=despair, B=black force, W=white force

	my @ABILITY = (
		['s'], ['a'],
		[ 's', 'a' ],
		[ 's', 's' ],
		['a'], ['s'], [ 'a', 'a' ], []
	);
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
	my @DIFFICULTY = (
		['t'], ['f'], [ 't', 'f' ],
		['t'], [],
		[ 't', 't' ],
		[ 'f', 'f' ], ['t']
	);
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
	my @FORCE = (
		['B'], [ 'W', 'W' ], ['B'], [ 'W', 'W' ], ['B'], [ 'W', 'W' ],
		['B'], ['W'], ['B'], ['W'], ['B'], [ 'B', 'B' ]
	);

	foreach ( 1 .. $self->{'Ability'}->GetValue() ) {
		push @result, @{ $ABILITY[ int( rand(@ABILITY) ) ] };
	}
	foreach ( 1 .. $self->{'Proficiency'}->GetValue() ) {
		push @result, @{ $PROFICIENCY[ int( rand(@PROFICIENCY) ) ] };
	}
	foreach ( 1 .. $self->{'Boost'}->GetValue() ) {
		push @result, @{ $BOOST[ int( rand(@BOOST) ) ] };
	}
	foreach ( 1 .. $self->{'Difficulty'}->GetValue() ) {
		push @result, @{ $DIFFICULTY[ int( rand(@DIFFICULTY) ) ] };
	}
	foreach ( 1 .. $self->{'Challenge'}->GetValue() ) {
		push @result, @{ $CHALLENGE[ int( rand(@CHALLENGE) ) ] };
	}
	foreach ( 1 .. $self->{'Setback'}->GetValue() ) {
		push @result, @{ $SETBACK[ int( rand(@SETBACK) ) ] };
	}
	foreach ( 1 .. $self->{'Force'}->GetValue() ) {
		push @result, @{ $FORCE[ int( rand(@FORCE) ) ] };
	}

	my $filter = 1;
	foreach my $rb ( @{ $self->{filter} } ) {
		if ( $rb->GetValue() ) {
			if ( $rb->GetLabel() =~ /^don/i ) {
				$filter = 0;
			}
		}
	}
	if ($filter) {
		my $string;
		my $s = grep( /s/, @result );
		my $f = grep( /f/, @result );
		if ( $s > $f ) {
			foreach ( 1 .. $s - $f ) {
				$string .= 's';
			}
		}
		if ( $s < $f ) {
			foreach ( 1 .. $f - $s ) {
				$string .= 'f';
			}
		}
		my $a = grep( /a/, @result );
		my $t = grep( /t/, @result );
		if ( $a > $t ) {
			foreach ( 1 .. $a - $t ) {
				$string .= 'a';
			}
		}
		if ( $a < $t ) {
			foreach ( 1 .. $t - $a ) {
				$string .= 't';
			}
		}
		$string .= join( '', grep( /T/, @result ) );
		$string .= join( '', grep( /D/, @result ) );
		$string .= join( '', grep( /B/, @result ) );
		$string .= join( '', grep( /W/, @result ) );
		$self->{'results'}->SetValue($string);
	}
	else {
		$self->{'results'}->SetValue( join( '', sort @result ) );
	}
}
1;