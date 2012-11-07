#!/bin/env perl
use strict;

use lib '.';

use HTML::TableExtract;
use LWP::Simple;

#my $odir         = '/www/www/sites/all/libraries/rpgnowads/rpgnowads.txt';
my $odir         = 'rpgnowads.txt';
my $affiliate_id = 'affiliate_id=279284';
my @output;

my @urls = (
	{
		page => "shadowrun",
		url  => 'http://www.rpgnow.com/index.php?filters=0_0_1720_0_0'
	},
	{
		page => "savageworlds",
		url  => 'http://www.rpgnow.com/index.php?filters=0_0_1600_0_0',

	},
	{
		page => "d6system",
		url  => 'http://www.rpgnow.com/index.php?filters=0_0_10020_0_0'
	},
	{
		page => "l5r",
		url  =>
'http://www.rpgnow.com/index.php?manufacturers_id=22&filters=0_0_10109_0_0'
	},
	{
		page => "fiction",
		url  => 'http://www.rpgnow.com/index.php?filters=41215_41080_41045_0'
	}
);

foreach my $url (@urls) {
	my $content = get( $url->{url} );
	if ( defined($content) ) {
		my $count = 0;
		my $te    = HTML::TableExtract->new(
			attribs   => { class => "infoBoxContents" },
			depth     => 4,
			keep_html => 1
		);

		my $js_table = HTML::TableExtract->new(
			attribs   => { border => 0, width => 200 },
			keep_html => 0
		);

		$te->parse($content);
		my $ts = $te->first_table_found();

		foreach my $fields ( $ts->rows() ) {
			foreach my $data (@$fields) {
				my ( $link, $title, $image, $price );

				if ( $data =~
					/(<span class="productSpecialPrice">.*?<\/span>)/i )
				{
					$price = $1;
					$data =~ /(<span class="productStrikePrice".*?<\/span>)/i;
					$price .= " ".$1;
					print "$price\n";
				}
				elsif ( $data =~ /(\$[\d]{0,}\.[\d]{2})/i ) {
					print "$1\n";
					$price = $1;
				}

				if ( $data =~ /a href="([\S]+)"/ ) {
					$link = $1;
				}
				if ( $data =~ /title="(.*?)"/ ) {
					$title = $1;
				}

				$data =~ s/onmouseover=.*?;">//g;
				if ( $data =~ /img src="([\S]+)"/ ) {
					$image = $1;
				}

				if (   $link !~ /^[\s]*$/
					&& $title !~ /^[\s]*$/
					&& $image !~ /^[\s]*$/ )
				{
					if ( $count < 10 ) {
						push @output,
						  '<div class="rpgnowad"><a href="' . $link . '&'
						  . $affiliate_id
						  . '"><img class="rpgnowadimage" src="http://www.rpgnow.com/'
						  . $image
						  . '"><br/>'
						  . $title . "<br>"
						  . $price
						  . "</a></div>";
						$count++;
					}
				}
			}
		}
	}
}

if ( @output >= 5 * @urls ) {
	open FH, '>' . $odir or die();
	print FH
'<div class="rpgnowcontainer"><h2 class="block-title">RPGNow Latest Products</h2>
';
	print FH join( "\n", @output ) . "\n</div>";
}
