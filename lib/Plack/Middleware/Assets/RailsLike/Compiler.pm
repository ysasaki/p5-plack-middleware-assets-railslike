package Plack::Middleware::Assets::RailsLike::Compiler;

use strict;
use warnings;
use Carp              ();
use CSS::Minifier::XS ();
use Errno             ();
use File::Slurp;
use File::Spec::Functions qw(catdir catfile canonpath);
use JavaScript::Minifier::XS ();
use Test::More;

sub new {
    my $class = shift;
    my %args  = (
        minify      => 0,
        search_path => ['.'],
        @_
    );
    bless \%args, $class;
}

sub compile {
    my $self = shift;
    my %args = (
        manifest => undef,
        type     => 'js',
        @_
    );

    my $content = $args{manifest};

    if ( $args{type} eq 'css' ) {
        my $css_comment = qr!
            /\*
              .*?
              (?:\r?\n)
              ((?:\*= .+(?:\r?\n)){1,})
            \*/
        !x;
        $content =~ s{$css_comment}{$1}g;
    }

    my $parser = qr{
        ^
            (?://|\*)=
            \s+
            (require)           # commands
            \s+
            ([0-9a-zA-Z_\-./]+) # basename
            \s*
        $
    }xms;

    $content
        =~ s/$parser/my $cmd = "_cmd_$1"; $self->$cmd($2, $args{type})/ge;

    $content = $self->_minify( $content, $args{type} ) if $self->{minify};
    return $content;
}

sub _cmd_require {
    my $self = shift;
    my ( $file, $type ) = @_;

    my @search_path = @{ $self->{search_path} };

    for my $path (@search_path) {

        my $filename
            = canonpath( catfile( $path, sprintf( '%s.%s', $file, $type ) ) );

        my $buff;
        read_file( $filename, buf_ref => \$buff, err_mode => sub { } );
        unless ($!) {
            chomp $buff;
            return $buff;
        }
        elsif ( $!{ENOENT} ) {
            next;
        }
        else {
            Carp::carp("read_file '$filename' failed - $!");
            return;
        }
    }

    Carp::carp( sprintf "requires '%s' failed - No such file in %s",
        $file, join( ', ', @search_path ) );
}

sub _minify {
    my $self = shift;
    my ( $content, $type ) = @_;
    if ( $type eq 'js' ) {
        $content = JavaScript::Minifier::XS::minify($content);
    }
    else {
        $content = CSS::Minifier::XS::minify($content);
    }
    return $content;
}

1;