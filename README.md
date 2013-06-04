# NAME

Plack::Middleware::Assets::RailsLike - Bundle and minify JavaScript and CSS files

# SYNOPSIS

    use strict;
    use warnings;
    use MyApp;
    use Plack::Builder;
    use Cache::MemoryCache;

    my $app = MyApp->new->to_app;
    

    builder {
        enable 'Assets::RailsLike',
            cache  => Cache::MemoryCache->new({ namespace=>'myapp' }),
            path   => qr{^/assets},
            root   => './htdocs',
            minify => 1;
        $app;
    };

# DESCRIPTION

__THIS MODULE IS STILL ALPHA. DO NOT USE THIS MODULE IN PRODUCTION.__

Plack::Middleware::Assets::RailsLike is a Plack middleware to bundle and minify 
javascript and css files like Ruby on Rails Assets Pipeline.

If manifest files were requested, bundle files in manifest file and serve it or
serve bundled data from cache.

Manifest file is a list of javascript and css files you want to bundle.

    > cat ./htdocs/assets/main-page.js
    requires 'jquery';
    requires 'myapp';

If _/assets/main-page.js_ was requested, find _jquery.js_, _myapp.js_ from search path (default search path is `$root`/assets).

# DEPENDENCIES

[Plack](http://search.cpan.org/perldoc?Plack), [Cache::Cache](http://search.cpan.org/perldoc?Cache::Cache), [File::Slurp](http://search.cpan.org/perldoc?File::Slurp), [JavaScript::Minifier::XS](http://search.cpan.org/perldoc?JavaScript::Minifier::XS), [CSS::Minifier::XS](http://search.cpan.org/perldoc?CSS::Minifier::XS)

# LICENSE

Copyright (C) 2013 Yoshihiro Sasaki

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Yoshihiro Sasaki <ysasaki@cpan.org>
