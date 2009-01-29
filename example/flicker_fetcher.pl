#/usr/bin/perl 
use strict;
use warnings;

use FlickrFetcher;
my $fetcher = FlickrFetcher->new_with_options();
$fetcher->run();
