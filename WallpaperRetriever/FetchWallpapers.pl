#!/bin/env perl
use strict;
use WWW::Mechanize;
use File::Path qw(make_path);

use threads;
use Thread::Queue;
use threads::shared;

my $artist_queue = Thread::Queue->new();
my $image_queue  = Thread::Queue->new();

my $root_www : shared = "http://wall.alphacoders.com/";
my @artists : shared;
my @images : shared;

my $agent = WWW::Mechanize->new(
	agent       => "Linux Mozilla",
	stack_depth => 5,
	onerror     => undef,
);

$agent->get($root_www);
enqueue_links($agent);

my $art_thread   = threads->create( \&artist_pages );
my $image_thread = threads->create( \&image_pages );

while ( $art_thread->is_running() || $image_thread->is_running() ) {
	sleep(30);
}

sub artist_pages {

	my $art_agent = WWW::Mechanize->new(
		agent       => "Linux Mozilla",
		stack_depth => 5,
		onerror     => undef,
	);

	while ( my $link = $artist_queue->dequeue() ) {
		if ( $link->url() =~ qr/users\/profile\/([\d]+)/i ) {
			my $id = $1;
			if ( !$artists[$id] ) {
				$art_agent->get( $link->url() );
				enqueue_links($art_agent);

				$art_agent->get( $root_www . "profile.php?id=" . $id );
				enqueue_links($art_agent);
				my @pages =
				  $art_agent->find_all_links(
					url_regex => qr/profile.php\?id=[\d]+&page=[\d]+/i );
				foreach my $page (@pages) {
					$art_agent->get( $page->url() );
					enqueue_links($art_agent);
				}
				$artists[$id]++;
				sleep(45);
			}
		}
	}
}

sub image_pages {
	my $image_agent = WWW::Mechanize->new(
		agent       => "Linux Mozilla",
		stack_depth => 5,
		onerror     => undef,
	);

	while ( my $link = $image_queue->dequeue() ) {
		if ( $link->url() =~ qr/big\.php\?i=([\d]+)/i ) {
			my $id = $1;
			if ( !$images[$id] ) {
				$image_agent->get( $link->url() );
				enqueue_links($image_agent);

				$image_agent->get( $root_www . "wallpaper.php?i=" . $id );
				enqueue_links($image_agent);
				my $subdir = substr( $id, 0, 3 );
				if ( !-e "wallpapers/$subdir/$id.jpg" || !-s >0) {
					my $im =
					  $image_agent->find_image( url_regex => qr/$subdir\/$id/ );
					if ( defined($im) ) {
						$image_agent->get( $im->url() );
						if ( $image_agent->success() ) {
							make_path( "wallpapers/" . $subdir );
							open FH, ">wallpapers/$subdir/$id.jpg";
							binmode FH;
							print FH $image_agent->content();
							close FH;

							#$image_agent->save_content();
							$images[$id]++;
							sleep(10);
						}
					}
				}
				else {
					$images[$id]++;
					print "Skipping $id as it was already downloaded\n";
				}
			}
		}
	}
}

sub enqueue_links {
	my $agent = shift;
	if ( $agent->success() ) {
		my @links =
		  $agent->find_all_links( url_regex => qr/big\.php\?i=[\d]+/i );
		foreach my $link (@links) {
			if ( $link->url() =~ qr/big\.php\?i=([\d]+)/i ) {
				if ( !$images[$1] ) {
					$image_queue->enqueue($link);
				}
			}
		}

		my @links =
		  $agent->find_all_links( url_regex => qr/users\/profile\/[\d]+/i );
		foreach my $link (@links) {
			if ( $link->url() =~ qr/users\/profile\/([\d]+)/i ) {
				if ( !$artists[$1] ) {
					$artist_queue->enqueue($link);
				}
			}
		}
	}
	print $artist_queue->pending() . "\n" . $image_queue->pending() . "\n";
}
