package FlickrFetcher;

use Moose;
use Moose::Util::TypeConstraints;
use Params::Coerce ();

use Coro::LWP;
use Coro;
use Coro::AnyEvent;

use Digest::MD5 qw(md5_hex);
use Encode;
use LWP::UserAgent;
use Path::Class;
use POSIX qw(ceil);
use WebService::Simple;
use WebService::Simple::Parser::XML::Simple;
use XML::Simple;

our $VERSION = '0.01';

with 'MooseX::Getopt';

subtype 'Dir' => as 'Object' => where { $_->isa('Path::Class::Dir') };
coerce 'Dir'  => from 'Str'  => via   { Path::Class::Dir->new($_) };

MooseX::Getopt::OptionTypeMap->add_option_type_to_map( 'Dir' => '=s' );

has 'keyword' => ( is => 'rw', isa => 'Str', required => 1 );
has 'dir' => ( is => 'rw', isa => 'Dir', required => 1, coerce => 1 );
has 'api_key'  => ( is => 'rw', isa => 'Str' );
has 'license'  => ( is => 'rw', isa => 'Int' );
has '_perpage' => ( is => 'ro', isa => 'Int', default => 500 );
has '_flickr'  => ( is => 'rw', isa => 'WebService::Simple' );
has '_ua' => (
    is      => 'ro',
    isa     => 'LWP::UserAgent',
    default => sub { LWP::UserAgent->new( keep_alive => 1 ) }
);

before run => sub {
    my $self = shift;
    mkdir $self->dir->relative if !-d $self->dir->is_absolute;
};

__PACKAGE__->meta->make_immutable;
no Moose;

sub BUILD {
    my ( $self, $args ) = @_;

    unless ( $self->api_key ) {
        if ( my $api_key = $ENV{FLICKR_API_KEY} ) {
            $self->api_key($api_key);
        }
        else {
            die "api_key is required\n";
        }
    }

    my $xs = XML::Simple->new( KeepRoot => 1, keyattr => [], ForceArray => ['photo'] );
    my $parser = WebService::Simple::Parser::XML::Simple->new( xs => $xs );
    my $flickr = WebService::Simple->new(
        base_url        => "http://api.flickr.com/services/rest/",
        param           => { api_key => $self->api_key },
        response_parser => $parser,
    );
    $self->_flickr($flickr);

}

sub run {
    my $self = shift;
    warn "search keyword : " . $self->keyword . "\n";
    my $photo_total = $self->photo_total( $self->keyword );
    warn "total count : " . $photo_total . "\n";
    my $pages = ceil( $photo_total / $self->_perpage );
    for my $current_page ( 1 .. $pages ) {
        warn "search page : $current_page\n";
        $self->search( $self->keyword, $current_page, $self->_perpage );
    }
}

sub search {
    my ( $self, $keyword, $page, $perpage ) = @_;
    my $response = $self->_flickr->get(
        {
            method   => "flickr.photos.search",
            text     => $keyword,
            per_page => $perpage,
            sort     => 'date-posted-desc',
            extras   => 'date_upload',
            page     => $page,
            license  => $self->license || "",
        }
    );
    my $xml = $response->parse_response;
    $self->fetch( $xml->{rsp}->{photos}->{photo} );
}

sub fetch {
    my ( $self, $photo_ref ) = @_;
    my @pids;
    for my $photo ( @$photo_ref ){
        my $url  = $self->photo_url( $photo->{id} );
        my $file = $self->dir->file( md5_hex($url) . ".jpg" );
        push( @pids, async {
            my $res  = $self->_ua->get( $url, ':content_file' => $file->stringify );
            warn "try to fetch : " . $res->status_line . " : $url\n";
        } );
    }
    $_->join for @pids;
}

sub photo_url {
    my ( $self, $photo_id ) = @_;
    my $response = $self->_flickr->get(
        {
            method   => "flickr.photos.getSizes",
            photo_id => $photo_id
        }
    );
    my $xml         = $response->parse_response;
    my $largest_ref = pop @{ $xml->{rsp}->{sizes}->{size} };
    return $largest_ref->{source};
}

sub photo_total {
    my ( $self, $keyword ) = @_;
    my $response = $self->_flickr->get(
        {
            method   => "flickr.photos.search",
            text     => $keyword,
            per_page => 1,
            license => $self->license || "",
        }
    );
    my $xml = $response->parse_response;
    return $xml->{rsp}->{photos}->{total};
}

1;

__END__

=head1 NAME

FlickrFetcher -

=head1 SYNOPSIS

  use FlickrFetcher;
  my $fetcher = FlickrFetcher->new_with_options();
  $fetcher->run();

=head1 DESCRIPTION

FlickrFetcher is

=head1 AUTHOR

Yusuke Wada E<lt>yusuke at kamawada.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
