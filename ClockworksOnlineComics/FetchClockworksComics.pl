use strict;
use WWW::Mechanize;
use File::Basename;

my $agent = WWW::Mechanize->new(
	agent       => "Linux Mozilla",
	stack_depth => 5
);

my $img_agent = WWW::Mechanize->new(
	agent       => "Linux Mozilla",
	stack_depth => 5
);

my $start = "http://shawntionary.com/clockworks/?p=31";

$agent->get($start);
if ( $agent->success() ) {
	while ( $agent->find_link( text_regex => qr/next/i ) ) {
		my @images =
		  $agent->find_all_images(
			url_regex => qr/shawntionary\.com\/clockworks\/comics/i );
		foreach my $img (@images) {
			my $name = basename( $img->url );
			print $img->url() . "\t" . $name . "\n";
			next if ( -e $name );
			$img_agent->get( $img->url() );
			if ( $img_agent->success() ) {
				open FH, ">$name";
				binmode FH;
				print FH $img_agent->content();
				close FH;
			}
		}
		$agent->get( $agent->find_link( text_regex => qr/next/i ) );
	}
}
