#/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use FlickrFetcher;
my $fetcher = FlickrFetcher->new_with_options();
$fetcher->run();
