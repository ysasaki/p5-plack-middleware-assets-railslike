package Plack::Middleware::Assets::RailsLike;

use 5.010_001;
use strict;
use warnings;
use parent 'Plack::Middleware';
use Plack::Util::Accessor qw(path root search_path cache expires minify);
use Cache::MemoryCache;
use Carp ();
use CSS::Minifier::XS ();
use Errno ();
use File::Basename;
use File::Slurp;
use File::Spec::Functions qw(catdir catfile canonpath);
use JavaScript::Minifier::XS ();

our $VERSION = "0.01";

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    # Set default values for options
    $self->{path}        ||= qr{^/assets};
    $self->{root}        ||= '.';
    $self->{search_path} ||= [catdir($self->{root},'assets')],
    $self->{minify}      ||= 0;
    $self->{expires}     ||= '3 days';
    $self->{cache}       ||= Cache::MemoryCache->new(
        {   namespace          => __PACKAGE__,
            default_expires_in => $self->{expires},
        }
    );

    return $self;
}

sub call {
    my ( $self, $env ) = @_;

    my $path_info = $env->{PATH_INFO};
    if ( $path_info =~ $self->path ) {
        my $real_path = canonpath( catfile( $self->root, $path_info ) );
        return $self->_build_content($real_path);
    }
    else {
        return $self->app->($env);
    }
}

sub _build_content {
    my $self = shift;
    my ($real_path) = @_;

    my ( $filename, $dirs, $suffix ) = fileparse( $real_path, qr/\.[^.]*/ );
    my $type = $suffix eq '.js' ? 'js' : 'css';

    my $content = $self->cache->get($real_path) || do {
        my $manifest = read_file($real_path);
        my $content = $self->_parse_manifest( $real_path, $manifest, $type );
        if ( $self->minify ) {
            my $minifier
                = $type eq 'js'
                ? 'JavaScript::Minifier::XS::minify'
                : 'CSS::Minifier::XS::minify';
            no strict 'refs';
            $content = $minifier->($content);
        }
        $self->cache->set( $real_path, $content );
        $content;
    };

    my $content_type = $type eq 'js' ? 'application/javascript' : 'text/css';
    return [
        200,
        [ 'Content-Type', $content_type, 'Content-Length', length($content) ],
        [$content]
    ];
}

my $file_id = 0;

sub _parse_manifest {
    my $self = shift;
    my ( $real_path, $manifest, $type ) = @_;

    # copy from cpanm
    my ( $asset, $error );
    {
        local $@;
        $asset = eval sprintf <<EOM, $file_id++;
package Plack::Middleware::Assets::RailsLike::Asset%d;
no warnings;
my \$result;
BEGIN { Plack::Middleware::Assets::RailsLike::Asset->import(\\\$result) };

# line 1 "$real_path"
$manifest;

\$result;
EOM
        $error = $@;
    }
    if ($error) { die "Parsing $real_path failed: $error" }

    return $asset->to_string(
        type        => $type,
        search_path => $self->search_path
    );
}

package Plack::Middleware::Assets::RailsLike::Asset;

use strict;
use warnings;
use File::Basename;
use File::Slurp;
use File::Spec::Functions qw(catfile canonpath);

my @bindings = qw(requires);

sub import {
    my ( $class, $result_ref ) = @_;
    my $pkg = caller;

    $$result_ref = Plack::Middleware::Assets::RailsLike::Asset->new;

    for my $binding (@bindings) {
        no strict 'refs';
        *{"$pkg\::$binding"} = sub { $$result_ref->$binding(@_) };
    }
}

sub new {
    my $class = shift;
    bless {}, $class;
}

sub to_string {
    my $self = shift;
    my %args = (
        search_path => ['.'],
        type        => 'js',
        @_
    );

    my $type = $args{type};

    my $content = '';
    for my $file ( @{ $self->{requires} } ) {
        my $asset_exists = 0;
        for my $path ( @{ $args{search_path} } ) {

            my $filename = canonpath(
                catfile( $path, sprintf( '%s.%s', $file, $type ) ) );

            my $buff;
            read_file( $filename, buf_ref => \$buff, err_mode => sub { } );
            unless ($!) {
                $asset_exists = 1;
                $content .= $buff;
                last;
            }
            elsif ( $!{ENOENT} ) {
                next;
            }
            else {
                $asset_exists = 1;
                Carp::carp("read_file '$filename' failed - $!");
                last;
            }
        }
        unless ($asset_exists) {
            Carp::carp( sprintf "requires '%s' failed - No such file in %s",
                $file, join( ', ', @{ $args{search_path} } ) );
        }
    }
    return $content;
}

# bindings
sub requires {
    my ( $self, $file ) = @_;
    push @{ $self->{requires} }, $file;
}

1;
__END__

=encoding utf-8

=head1 NAME

Plack::Middleware::Assets::RailsLike - Bundle and minify JavaScript and CSS files

=head1 SYNOPSIS

    use strict;
    use warnings;
    use MyApp;
    use Plack::Builder;

    my $app = MyApp->new->to_app;
    
    builder {
        enable 'Assets::RailsLike', root => './htdocs', minify => 1;
        $app;
    };

=head1 DESCRIPTION

B<THIS MODULE IS STILL ALPHA. DO NOT USE THIS MODULE IN PRODUCTION.>

Plack::Middleware::Assets::RailsLike is a Plack middleware to bundle and minify 
javascript and css files like Ruby on Rails Assets Pipeline.

If manifest files were requested, bundle files in manifest file and serve it or
serve bundled data from cache.

Manifest file is a list of javascript and css files you want to bundle.

    > cat ./htdocs/assets/main-page.js
    requires 'jquery';
    requires 'myapp';

If I</assets/main-page.js> was requested, find I<jquery.js>, I<myapp.js> from search path (default search path is C<$root>/assets).

=head1 CONFIGURATIONS

=over 4

=item root

Document root to find manifest files to serve.

Default value is current directory('.').

=item path

The URL pattern (regular expression) for matching.

Default value is C<qr{^/assets}>.

=item search_path

Paths to find javascript and css files.

Default value is C<[qw($root/assets)]>.

=item minify

Minify javascript and css files if true.

Default value is C<0>.

=item cache

Cache bundled/minified data in memory. The C<cache> object must be implemented C<get> and C<set> methods.

Default is a C<Cache::MemoryCache> Object.

    Cache::MemoryCache->new({
        namespace          => "Plack::Middleware::Assets::RailsLike",
        default_expires_in => $expires
    })

=item expires

Expiration of cache.

Default is 3 days.

=back

=head1 DEPENDENCIES

L<Plack>, L<Cache::Cache>, L<File::Slurp>, L<JavaScript::Minifier::XS>, L<CSS::Minifier::XS>

=head1 LICENSE

Copyright (C) 2013 Yoshihiro Sasaki

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Yoshihiro Sasaki E<lt>ysasaki@cpan.orgE<gt>

=cut

