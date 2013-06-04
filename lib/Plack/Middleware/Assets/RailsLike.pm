package Plack::Middleware::Assets::RailsLike;

use 5.008005;
use strict;
use warnings;
use parent 'Plack::Middleware';
use Plack::Util::Accessor qw(path root cache minify);
use Cache::MemoryCache;
use CSS::Minifier::XS ();
use File::Basename;
use File::Slurp;
use File::Spec::Functions qw(catfile canonpath);
use JavaScript::Minifier::XS ();

our $VERSION = "0.01";

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

    $self->{cache}
        ||= Cache::MemoryCache->new( { namespace => __PACKAGE__ } );

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

    return $asset->to_string( path => $real_path, type => $type );
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
        path => undef,
        type => 'js',
        @_
    );

    my $type = $args{type};
    my @path = ( fileparse( $args{path} ) )[1];

    my $content = '';
    for my $file ( @{ $self->{requires} } ) {
        my $real_path = canonpath(
            catfile( @path,, sprintf( '%s.%s', $file, $type ) ) );

        # '' => Suppress "Use of uninitialized value"
        $content .= read_file( $real_path, err_mode => 'carp' ) || '';
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

Plack::Middleware::Assets::RailsLike - It's new $module

=head1 SYNOPSIS

    use Plack::Middleware::Assets::RailsLike;

=head1 DESCRIPTION

Plack::Middleware::Assets::RailsLike is ...

=head1 LICENSE

Copyright (C) Yoshihiro Sasaki

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Yoshihiro Sasaki E<lt>ysasaki@cpan.orgE<gt>

=cut

