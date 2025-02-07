#!/bin/env perl
use strict;
use WWW::Mechanize;
use File::Path qw(make_path);
use File::Find;
use File::Basename;

use threads;
use Thread::Queue;
use threads::shared;

=head1 NAME

FetchWallpapers - A program to find and download all the wallpapers from
http://wall.alphacoders.com

=head1 SYNOPSIS

FetchWallpapers uses Mechanize and Perl threads to scrape through the Alphacoders
website to grab all the images that people have uploaded to it. The methodology
used by this program allows it to find pages without making any assumptions from
the initial launch. It starts by reading the homepage and from there spiders out
to find more pages and links based on what is linked on the homepage at the time.

=head1 DESCRIPTION

=head1 COPYRIGHT

Copyright 2012 Kevin Brown.

Permission is granted to copy, distribute and/or modify this 
document under the terms of the GNU Free Documentation 
License, Version 2.0 or any later version published by the 
Free Software Foundation; with no Invariant Sections, with 
no Front-Cover Texts, and with no Back-Cover Texts.

=cut

my $artist_queue = Thread::Queue->new();
my $image_queue  = Thread::Queue->new();

my $root_www : shared = "http://wall.alphacoders.com/";
my @artists : shared;
my @images : shared;
my @enqueued : shared;
my $downloaded:shared;
my $skipped:shared;
my $error:shared;

my $agent = WWW::Mechanize->new(
	agent       => "Linux Mozilla",
	stack_depth => 5,
	onerror     => undef,
);

$agent->get($root_www);
enqueue_links($agent);

my $art_thread   = threads->create( { 'void' => 1 }, \&artist_pages );
my $image_thread = threads->create( { 'void' => 1 }, \&image_pages );
my $scan_thread = threads->create( { 'void' => 1 }, \&rescan_directory );

while ( $art_thread->is_running() || $image_thread->is_running() ) {
	if ( $image_queue->pending() == 0 && $artist_queue->pending() == 0 ) {
		$image_queue->enqueue(undef);
		$artist_queue->enqueue(undef);
		foreach my $thread ( threads->list() ) {
			$thread->join();
		}
		print "Downloaded Images: $downloaded\nSkipped Images: $skipped\nErrors: $error\n";
	}
	print $artist_queue->pending() . "\t" . $image_queue->pending() . "\n";
	sleep(30);
}

=head2 artist_pages

When an artist profile is enqueued, artist_pages parses it to find other artists
and wallpaper images by looking at the favorites list of that artist, the people
who have left comments on that page and the actual artwork uploaded by that 
artist.

=cut

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
			}
		}
	}
}

=head2 image_pages

image_pages enqueues new found wallpapers and artists by checking queued images 
for comments and other favorited images.

=cut

sub image_pages {
	my $image_agent = WWW::Mechanize->new(
		agent       => "Linux Mozilla",
		stack_depth => 5,
		onerror     => undef,
	);

	while (my $link = $image_queue->dequeue()) {
		if ( $link->url() =~ qr/big\.php\?i=([\d]+)/i ) {
			my $id = $1;
			if ( !$images[$id] ) {
				$image_agent->get( $link->url() );
				enqueue_links($image_agent);

				$image_agent->get( $root_www . "wallpaper.php?i=" . $id );
				enqueue_links($image_agent);
				my $subdir = substr( $id, 0, 3 );
				if ( !-e "wallpapers/$subdir/$id.jpg"
					|| -s "wallpapers/$subdir/$id.jpg" < 10000 )
				{
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

							print "Saved image $id\n";

							$images[$id]++;
							$downloaded++;
						}
					}
					else {
						$images[$id]++;
						#print "No wallpaper with ID $id\n";
						$error++;
					}
				}
				else {
					$images[$id]++;
					#print "Skipping $id as it was already downloaded\n";
					$skipped++;
				}
			}
		}
		else {
			print $link->url() . "\n";
			$error++;
		}
	}
}

=head2

enqueue_links reads through the page content and queues up the found links from
the page based on two patterns. One pattern is for actual wallpaper pages, the 
other is for artist pages. Before queueing up the link, it checks a shared array
to see if that page has already been dug through before. This reduces some 
redundancy that the program might accidently go through otherwise.

=cut

sub enqueue_links {
	my $agent = shift;
	if ( $agent->success() ) {
		my @links =
		  $agent->find_all_links( url_regex => qr/big\.php\?i=[\d]+/i );
		foreach my $link (@links) {
			if ( $link->url() =~ qr/big\.php\?i=([\d]+)/i ) {
				if ( !( $images[$1] || $enqueued[$1] ) ) {
					$image_queue->enqueue($link);
					$enqueued[$1]++;
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
}

sub rescan_directory {
	find( { wanted => \&readd_image, no_chdir => 1 }, "wallpapers/" );
}

sub readd_image {
	my $name = fileparse( $_, qr/\.[^.]*/ );
	if ( $name =~ /^[\d]+$/ ) {

		my $link = WWW::Mechanize::Link->new(
			{
				url  => $root_www . "big.php?i=" . $name,
				name => $name,
				base => $root_www,
			}
		);
		$image_queue->enqueue($link);
		$enqueued[$1]++;
	}
}
