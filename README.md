# NAME

Plack::Middleware::Assets::RailsLike - Bundle and minify JavaScript and CSS files

# SYNOPSIS

    use strict;
    use warnings;
    use MyApp;
    use Plack::Builder;

    my $app = MyApp->new->to_app;
    

    builder {
        enable 'Assets::RailsLike', root => './htdocs';
        $app;
    };

# DESCRIPTION

__THIS MODULE IS STILL ALPHA. DO NOT USE THIS MODULE IN PRODUCTION.__

Plack::Middleware::Assets::RailsLike is a Plack middleware to bundle and minify 
javascript and css files like Ruby on Rails Assets Pipeline.

At first, you create a manifest file. The Manifest file is a list of javascript and css files you want to bundle. You can also use Sass and LESS as css files. The Manifest syntax is same as Rails Assets Pipeline, but only support `require` command.

    > vim ./htdocs/assets/main-page.js
    > cat ./htdocs/assets/main-page.js
    //= require jquery
    //= require myapp



Next, write a manifest file's url in your html. This middleware supports versioning. So you can add version string like this.

    <- $basename-$version$suffix ->
    <script type="text/javascript" src="/assets/main-page-v2013060701.js">

If manifest files were requested, bundle files in manifest file and serve it or serve bundled data from cache. In this case, find _jquery.js_, _myapp.js_ from search path (default search path is `$root`/assets).

# CONFIGURATIONS

- root

    Document root to find manifest files to serve.

    Default value is current directory('.').

- path

    The URL pattern (regular expression) for matching.

    Default value is `qr{^/assets}`.

- search\_path

    Paths to find javascript and css files.

    Default value is `[qw($root/assets)]`.

- minify

    Minify javascript and css files if true.

    Default value is `1`.

- cache

    Cache bundled/minified data in memory. The `cache` object must be implemented `get` and `set` methods.

    Default is a `Cache::MemoryCache` Object.

        Cache::MemoryCache->new({
            namespace           => "Plack::Middleware::Assets::RailsLike",
            default_expires_in  => $expires
            auto_purge_interval => '1 day',
            auto_purge_on_set   => 1,
            auto_purge_on_get   => 1
        })

- expires

    Expiration of cache and Expires header in HTTP response. See [Cache::Cache](http://search.cpan.org/perldoc?Cache::Cache) for more details.

    Default is 3 days.

# DEPENDENCIES

[Plack](http://search.cpan.org/perldoc?Plack), [Cache::Cache](http://search.cpan.org/perldoc?Cache::Cache), [File::Slurp](http://search.cpan.org/perldoc?File::Slurp), [JavaScript::Minifier::XS](http://search.cpan.org/perldoc?JavaScript::Minifier::XS), [CSS::Minifier::XS](http://search.cpan.org/perldoc?CSS::Minifier::XS), [Digest::SHA1](http://search.cpan.org/perldoc?Digest::SHA1), [HTTP::Date](http://search.cpan.org/perldoc?HTTP::Date), [Text::Sass](http://search.cpan.org/perldoc?Text::Sass), [CSS::LESSp](http://search.cpan.org/perldoc?CSS::LESSp)

# LICENSE

Copyright (C) 2013 Yoshihiro Sasaki

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Yoshihiro Sasaki <ysasaki@cpan.org>
