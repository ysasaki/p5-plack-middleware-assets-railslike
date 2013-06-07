use utf8;
use strict;
use warnings;
use t::Util qw(compiled_js compiled_css);
use Test::More;
use Test::Name::FromLine;
use Plack::Test;
use Plack::Builder;
use HTTP::Request::Common;
use Cache::MemoryCache;

my $cache = Cache::MemoryCache->new( { namespace => 'foo' } );
my $app = builder {
    enable 'Assets::RailsLike',
        cache  => $cache,
        root   => './t',
        minify => 0;
    sub { [ 200, [ 'Content-Type', 'text/html' ], ['OK'] ] };
};

test_psgi(
    app    => $app,
    client => sub {
        my $cb = shift;

        subtest 'javascript' => sub {
            my $res = $cb->( GET '/assets/application.js' );
            is $res->code,    200;
            is $res->content, compiled_js;
        };

        subtest 'css' => sub {
            my $res = $cb->( GET '/assets/application.css' );
            is $res->code,    200;
            is $res->content, compiled_css;
        };

        subtest 'with versioning' => sub {
            my $res = $cb->( GET '/assets/application-123456789.js' );
            is $res->code,    200;
            is $res->content, compiled_js;
        };
    }
);

sub cache_ok {
    my ( $name, $key, $expected ) = @_;
    subtest $name => sub {
        my $cached = $cache->get($key);
        is $cached, $expected;
    };
}

cache_ok( 'js cache',  't/assets/application.js',  compiled_js );
cache_ok( 'css cache', 't/assets/application.css', compiled_css );
cache_ok( 'with versioning cache',
    't/assets/application-123456789.js', compiled_js );

done_testing;
