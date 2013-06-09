package Plack::Middleware::Assets::RailsLike;

use 5.010_001;
use strict;
use warnings;
use parent 'Plack::Middleware';
use Cache::MemoryCache;
use Carp         ();
use Digest::SHA1 ();
use Errno        ();
use File::Basename;
use File::Slurp;
use File::Spec::Functions qw(catdir catfile canonpath);
use HTTP::Date ();
use Plack::Util::Accessor qw(path root search_path expires cache minify);
use Plack::Middleware::Assets::RailsLike::Compiler;

our $VERSION = "0.04";

our $EXPIRES_NEVER = $Cache::Cache::EXPIRES_NEVER;
our $EXPIRES_NOW   = $Cache::Cache::EXPIRES_NOW;

# copy from Cache::BaseCache
my %_expiration_units = (
    map( ( $_, 1 ),                  qw(s second seconds sec) ),
    map( ( $_, 60 ),                 qw(m minute minutes min) ),
    map( ( $_, 60 * 60 ),            qw(h hour hours) ),
    map( ( $_, 60 * 60 * 24 ),       qw(d day days) ),
    map( ( $_, 60 * 60 * 24 * 7 ),   qw(w week weeks) ),
    map( ( $_, 60 * 60 * 24 * 30 ),  qw(M month months) ),
    map( ( $_, 60 * 60 * 24 * 365 ), qw(y year years) )
);

sub prepare_app {
    my $self = shift;

    # Set default values for options
    $self->{path}        ||= qr{^/assets};
    $self->{root}        ||= '.';
    $self->{search_path} ||= [ catdir( $self->{root}, 'assets' ) ];
    $self->{expires}     ||= '3 days';
    $self->{cache}       ||= Cache::MemoryCache->new(
        {
            namespace           => __PACKAGE__,
            default_expires_in  => $self->{expires},
            auto_purge_interval => '1 day',
            auto_purge_on_set   => 1,
            auto_purge_on_get   => 1
        }
    );
    $self->{minify} //= 1;

    $self->{_compiler} = Plack::Middleware::Assets::RailsLike::Compiler->new(
        minify      => $self->{minify},
        search_path => $self->{search_path},
    );
}

sub call {
    my ( $self, $env ) = @_;

    my $path_info = $env->{PATH_INFO};
    if ( $path_info =~ $self->path ) {
        my $real_path = canonpath( catfile( $self->root, $path_info ) );
        my ( $filename, $dirs, $suffix )
            = fileparse( $real_path, qr/\.[^.]*/ );
        my $type = $suffix eq '.js' ? 'js' : 'css';

        my $content;
        {
            local $@;
            eval {
                $content
                    = $self->_build_content( $real_path, $filename, $dirs,
                    $suffix, $type );
            };
            if ($@) {
                warn $@;
                return $self->_500;
            }
        }
        return $self->_404 unless $content;

        my $etag = Digest::SHA1::sha1_hex($content);
        if ( $env->{'HTTP_IF_NONE_MATCH'} || '' eq $etag ) {
            return $self->_304;
        }
        else {
            return $self->_build_response( $content, $type, $etag );
        }
    }
    else {
        return $self->app->($env);
    }
}

sub _build_content {
    my $self = shift;
    my ( $real_path, $filename, $dirs, $suffix, $type ) = @_;
    my ( $base, $version ) = $filename =~ /^(.+)-([^\-]+)$/;

    my $content = $self->cache->get($real_path);
    return $content if $content;

    my ( @list, $pre_compiled );
    if ($version) {
        @list = ( $real_path, catfile( $dirs, "$base$suffix" ) );
        $pre_compiled = 1;
    }
    else {
        @list         = ($real_path);
        $pre_compiled = 0;
    }

    for my $file (@list) {
        my $manifest;
        read_file( $file, buf_ref => \$manifest, err_mode => sub { } );
        if ( $! and $!{ENOENT} ) {
            $pre_compiled = 0;
            next;
        }
        elsif ($!) {
            die "read_file '$file' failed - $!";
        }

        if ($pre_compiled) {
            $content = $manifest;
        }
        else {
            $content = $self->{_compiler}->compile(
                manifest => $manifest,
                type     => $type
            );
        }

        # filename with versioning as a key
        $self->cache->set( $real_path, $content );
        last;
    }
    return $content;
}

sub _build_response {
    my $self = shift;
    my ( $content, $type, $etag ) = @_;

    # build headers
    my $content_type = $type eq 'js' ? 'application/javascript' : 'text/css';
    my $max_age      = $self->_max_age;
    my $expires      = time + $max_age;

    return [
        200,
        [   'Content-Type'   => $content_type,
            'Content-Length' => length($content),
            'Cache-Control'  => sprintf( 'max-age=%d', $max_age ),
            'Expires'        => HTTP::Date::time2str($expires),
            'Etag'           => $etag,
        ],
        [$content]
    ];
}

my $file_id = 0;

sub _max_age {
    my $self    = shift;
    my $max_age = 0;
    if ( $self->expires ne $EXPIRES_NEVER and $self->expires ne $EXPIRES_NOW )
    {
        $max_age = $self->_expires_in_seconds;
    }
    elsif ( $self->expires eq $EXPIRES_NEVER ) {

        # See http://www.w3.org/Protocols/rfc2616/rfc2616.txt 14.21 Expires
        $max_age = $_expiration_units{'year'};
    }
    return $max_age;
}

sub _expires_in_seconds {
    my $self    = shift;
    my $expires = $self->expires;

    my ( $n, $unit ) = $expires =~ /^\s*(\d+)\s*(\w+)\s*$/;
    if ( $n && $unit && ( my $secs = $_expiration_units{$unit} ) ) {
        return $n * $secs;
    }
    elsif ( $expires =~ /^\s*(\d+)\s*$/ ) {
        return $expires;
    }
    else {
        Carp::carp "Invalid expiration time '$expires'";
        return 0;
    }
}

sub _304 {
    my $self = shift;
    $self->_response( 304, 'Not Modified' );
}

sub _404 {
    my $self = shift;
    $self->_response( 404, 'Not Found' );
}

sub _500 {
    my $self = shift;
    $self->_response( 500, 'Internal Server Error' );
}

sub _response {
    my $self = shift;
    my ( $code, $content ) = @_;
    return [
        $code,
        [   'Content-Type'   => 'text/plain',
            'Content-Length' => length($content)
        ],
        [$content]
    ];
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
        enable 'Assets::RailsLike', root => './htdocs';
        $app;
    };

=head1 DESCRIPTION

B<THIS MODULE IS STILL ALPHA. DO NOT USE THIS MODULE IN PRODUCTION.>

Plack::Middleware::Assets::RailsLike is a Plack middleware to bundle and minify 
javascript and css files like Ruby on Rails Assets Pipeline.

At first, you create a manifest file. The Manifest file is a list of javascript and css files you want to bundle. The Manifest syntax is same as Rails Assets Pipeline, but only support C<require> command.

    > vim ./htdocs/assets/main-page.js
    > cat ./htdocs/assets/main-page.js
    //= require jquery
    //= require myapp


Next, write a manifest file's url in your html. This middleware supports versioning. So you can add version string like this.

    <- $basename-$version$suffix ->
    <script type="text/javascript" src="/assets/main-page-v2013060701.js">

If manifest files were requested, bundle files in manifest file and serve it or serve bundled data from cache. In this case, find I<jquery.js>, I<myapp.js> from search path (default search path is C<$root>/assets).

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

Default value is C<1>.

=item cache

Cache bundled/minified data in memory. The C<cache> object must be implemented C<get> and C<set> methods.

Default is a C<Cache::MemoryCache> Object.

    Cache::MemoryCache->new({
        namespace           => "Plack::Middleware::Assets::RailsLike",
        default_expires_in  => $expires
        auto_purge_interval => '1 day',
        auto_purge_on_set   => 1,
        auto_purge_on_get   => 1
    })

=item expires

Expiration of cache and Expires header in HTTP response. See L<Cache::Cache> for more details.

Default is 3 days.

=back

=head1 DEPENDENCIES

L<Plack>, L<Cache::Cache>, L<File::Slurp>, L<JavaScript::Minifier::XS>, L<CSS::Minifier::XS>, L<Digest::SHA1>, L<HTTP::Date>

=head1 LICENSE

Copyright (C) 2013 Yoshihiro Sasaki

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Yoshihiro Sasaki E<lt>ysasaki@cpan.orgE<gt>

=cut

