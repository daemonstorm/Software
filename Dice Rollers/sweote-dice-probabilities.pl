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
	my $frame = QCPC::Frame->new(
		undef, -1,
		"Star Wars Dice Probabilities",
		[ 1,   1 ],
		[ 400, 400 ]
	);

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
		[ 220, 160 ],
		[ 160, 200 ],
		&Wx::wxTE_MULTILINE | &Wx::wxHSCROLL
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
		$panel,                                                       # parent
		1,                                                            # id
		"Minor notes:\na = Advantage\ns = Success\nT = Triumph\n",    # label
		[ 10, 180 ],                                                  # position
		[ 80, 80 ],
		&Wx::wxST_NO_AUTORESIZE,
	);
	Wx::StaticText->new(
		$panel,                                                       # parent
		1,                                                            # id
		"t = Threat\nf = Failure\nD = Despair",                       # label
		[ 90, 192 ],                                                  # position
		[ 80, 80 ],
		&Wx::wxST_NO_AUTORESIZE,
	);
	Wx::StaticText->new(
		$panel,                                                       # parent
		1,                                                            # id
"The success of the Triumph and the failure of the Despair is already accounted for. If the final result shows a Triumph, but not a Success, then the Triumph's Success was cancelled by a Failure\nSame thing for the Despair and its Failure"
		,                                                             # label
		[ 10,  250 ],                                                 # position
		[ 200, 140 ],
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
	my $self         = shift;
	my $combinations = 1;
	my @choices;
	my %stats;
	my %tally;

#s = success, f=failure, t=threat, a=advantage, T=triumph, D=despair, B=black force, W=white force

	my @ABILITY = ( 's', 'a', 'sa', 'ss', 'a', 's', 'aa', "" );
	my @PROFICIENCY =
	  ( 'aa', 'a', 'aa', 'sT', 's', 'sa', 's', 'sa', 'ss', 'sa', 'ss', "" );
	my @BOOST = ( 'a', 'sa', 'aa', 's', "", "" );
	my @DIFFICULTY = ( 't', 'f', 'tf', 't', "", 'tt', 'ff', 't' );
	my @CHALLENGE =
	  ( 'tt', 't', 'tt', 't', 'tf', 'f', 'tf', 'f', 'ff', 'fD', 'ff', "" );
	my @SETBACK = ( 'f', 't', 'f', 't', "", "" );
	my @FORCE =
	  ( 'B', 'WW', 'B', 'WW', 'B', 'WW', 'B', 'W', 'B', 'W', 'B', 'BB' );

	foreach ( 1 .. $self->{'Ability'}->GetValue() ) {
		$combinations *= @ABILITY;
		$choices[@choices] = \@ABILITY;
	}
	foreach ( 1 .. $self->{'Proficiency'}->GetValue() ) {
		$combinations *= @PROFICIENCY;
		$choices[@choices] = \@PROFICIENCY;
	}
	foreach ( 1 .. $self->{'Boost'}->GetValue() ) {
		$combinations *= @BOOST;
		$choices[@choices] = \@BOOST;
	}
	foreach ( 1 .. $self->{'Difficulty'}->GetValue() ) {
		$combinations *= @DIFFICULTY;
		$choices[@choices] = \@DIFFICULTY;
	}
	foreach ( 1 .. $self->{'Challenge'}->GetValue() ) {
		$combinations *= @CHALLENGE;
		$choices[@choices] = \@CHALLENGE;
	}
	foreach ( 1 .. $self->{'Setback'}->GetValue() ) {
		$combinations *= @SETBACK;
		$choices[@choices] = \@SETBACK;
	}
	foreach ( 1 .. $self->{'Force'}->GetValue() ) {
		$combinations *= @FORCE;
		$choices[@choices] = \@FORCE;
	}

	for ( my $i = 0 ; $i < $combinations ; $i++ ) {
		my $divider = $combinations;
		my $string;
		foreach my $choice (@choices) {
			$divider = $divider / @{$choice};
			$string .= ${$choice}[ int( $i / $divider ) % @{$choice} ];
		}
		my @temp = split( //, $string );
		my $s    = grep( /s/, @temp );
		my $f    = grep( /f/, @temp );
		if ( $s > $f ) {
			$tally{'Success'}++;
			foreach ( 1 .. $s - $f ) {
				$string .= 's';
			}
		}
		if ( $s < $f ) {
			$tally{'Failure'}++;
			foreach ( 1 .. $f - $s ) {
				$string .= 'f';
			}
		}
		my $a = grep( /a/, @temp );
		my $t = grep( /t/, @temp );
		if ( $a > $t ) {
			$tally{'Advantage'}++;
			foreach ( 1 .. $a - $t ) {
				$string .= 'a';
			}
		}
		if ( $a < $t ) {
			$tally{'Threat'}++;
			foreach ( 1 .. $t - $a ) {
				$string .= 't';
			}
		}
		$string .= join( '', grep( /T/, @temp ) );
		$string .= join( '', grep( /D/, @temp ) );
		$string .= join( '', grep( /B/, @temp ) );
		$string .= join( '', grep( /W/, @temp ) );
		$stats{$string}++;
	}
	my $string =
	    ( 100 * $stats{""} / $combinations ) . "\t"
	  . ( 100 * $tally{'Success'} / $combinations ) . "\t"
	  . ( 100 * $tally{'Failure'} / $combinations ) . "\t"
	  . ( 100 * $tally{'Advantage'} / $combinations ) . "\t"
	  . ( 100 * $tally{'Threat'} / $combinations ) . "\n";
	$self->{'results'}->SetValue($string);
	return;
}
1;
