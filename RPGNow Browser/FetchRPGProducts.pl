#!/usr/bin/perl
use strict;

use lib '.';

use HTML::TableExtract;
use LWP::Simple;

my $odir = '/home/daemonst/www/www/sites/all/libraries/rpgnowads/rpgnowads.txt';

#my $odir         = 'rpgnowads.txt';
my $affiliate_id = 'affiliate_id=279284';
my @output;

my @urls = (
	{
		page => "catalyst",
		url  =>
'http://www.rpgnow.com/includes/ajax/get_view_strip.php?view_strip=slider_view&strip_type=newest&manufacturers_id=44',
	},
	{
		page => "savageworlds",
		url  =>
'http://www.rpgnow.com/includes/ajax/get_view_strip.php?view_strip=slider_view&strip_type=newest&filters=0_0_1600_0_0',
	},
	{
		page => "old-school-dnd",
		url  =>
'http://www.rpgnow.com/includes/ajax/get_view_strip.php?view_strip=slider_view&strip_type=newest&manufacturers_id=44',
	},
	{
		page => "shadowrun",
		url  =>
'http://www.rpgnow.com/includes/ajax/get_view_strip.php?view_strip=slider_view&strip_type=newest&filters=0_0_1700_0_0',
	},
	{
		page => "fantasy-flight-games",
		url  =>
'http://www.rpgnow.com/includes/ajax/get_view_strip.php?view_strip=slider_view&strip_type=newest&manufacturers_id=6',
	},
	{
		page => "aeg",
		url  =>
'http://www.rpgnow.com/includes/ajax/get_view_strip.php?view_strip=slider_view&strip_type=newest&manufacturers_id=22',
	},
);

foreach my $url (@urls) {
	my $content = get( $url->{url} );
	if ( defined($content) ) {
		my $count = 0;
		my $te    = HTML::TableExtract->new(
			attribs => {
				cellspacing => 0,
				cellpadding => 4,
				border      => 0,
			},
			keep_html => 1
		);

		$te->parse($content);
		foreach my $ts ( $te->tables() ) {
			foreach my $fields ( $ts->rows() ) {
				foreach my $data (@$fields) {
					my ( $link, $title, $image, $price );

					if ( $data =~
						/(<span class="productSpecialPrice">.*?<\/span>)/i )
					{
						$price = $1;
						$data =~
						  /(<span class="productStrikePrice".*?<\/span>)/i;
						$price .= " " . $1;

						#print "$price\n";
					}
					elsif ( $data =~ /(\$[\d]{0,}\.[\d]{2})/i ) {

						#print "$1\n";
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
						if ( $link =~ /\?/ ) {
							$link .= '&' . $affiliate_id;
						}
						else {
							$link .= '?' . $affiliate_id;
						}
						push @output, '<div class="rpgnowad"><a href="' . $link
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
