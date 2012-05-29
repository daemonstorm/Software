#!/bin/env perl
use strict;
use HTML::TableExtract;
use LWP::Simple;

my $affiliate_id = 'affiliate_id=279284';

my @urls = (
	{
		page => "shadowrun",
		url  => 'http://rpg.drivethrustuff.com/index.php?filters=0_0_1720_0_0'
	},
	{
		page => "savageworlds",
		url  =>
'http://rpg.drivethrustuff.com/index.php?manufacturers_id=27&filters=0_0_1600_0_0'
	},
	{
		page => "d6system",
		url  => 'http://rpg.drivethrustuff.com/index.php?filters=0_0_10020_0_0'
	},
);

foreach my $url (@urls) {
	open FH, ">" . $url->{page};

	my $content = get( $url->{url} );
	my $count   = 0;
	my $te      = HTML::TableExtract->new(
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

	#print "Table found at ", join( ',', $ts->coords ), ":\n";

	print FH '<div class="rpgnowcontainer">';

	foreach my $fields ( $ts->rows() ) {
		foreach my $data (@$fields) {
			if ( $count < 5 ) {
				my ( $link, $title, $image );

				#print "$data\n";
				if ( $data =~ /a href="([\S]+)"/ ) {

					#print "$1\n";
					$link = $1;
				}
				if ( $data =~ /title="(.*?)"/ ) {
					$title = $1;

					#print "$title\n";
				}

				$data =~ s/onmouseover=.*?;">//g;
				if ( $data =~ /img src="([\S]+)"/ ) {

					#print "$1\n";
					$image = $1;
				}

				if (   $link !~ /^[\s]*$/
					&& $title !~ /^[\s]*$/
					&& $image !~ /^[\s]*$/ )
				{
					print $count++ ."\n";
					print FH '<div class="rpgnowad"><a href="' . $link . '&'
					  . $affiliate_id
					  . '"><img class="rpgnowad" src="http://www.rpgnow.com/'
					  . $image
					  . '"><br/>'
					  . $title
					  . "</a></div>\n";
				}
			}
		}
		print FH '</div>';
		close(FH);
	}
}
