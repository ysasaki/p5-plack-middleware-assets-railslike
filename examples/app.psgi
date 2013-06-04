use strict;
use warnings;
use Plack::Builder;

# Usage
# > carton install
# > carton exec -- ./local/bin/plackup -a app.psgi
# > open http://localhost:5000

my $html = <<HTML;
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Assets::RailsLike</title>
    <script src="/assets/main.js" type="text/javascript"></script>
</head>
<body><h1>Assets::RailsLike</h1></body>
</html>
HTML

builder {
    enable 'Assets::RailsLike',
        path   => qr{^/assets},
        root   => '.',
        minify => 1;
    sub { [ 200, [ 'Content-Type', 'text/html; charset=utf-8' ], [$html] ] };
};
