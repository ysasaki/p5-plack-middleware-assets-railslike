use utf8;
use strict;
use warnings;
use Test::More;
use Plack::Middleware::Assets::RailsLike;

my $assets = new_ok 'Plack::Middleware::Assets::RailsLike',
    [ { path => qr{/assets}, root => './t' } ];

can_ok $assets, $_ for qw(path root minify);

done_testing;
