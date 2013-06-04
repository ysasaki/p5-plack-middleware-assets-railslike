package t::Util;

use utf8;
use strict;
use warnings;
use parent 'Exporter';

use constant {
    compiled_js => <<JS,
var foo = 1;
function bar(name) {
    alert(name);
}
JS
    minified_js  => 'var foo=1;function bar(name){alert(name);}',
    compiled_css => <<CSS,
#foo {
    size: 5em;
}
.bar {
    height: 40%;
    width: 60%;
}
CSS
    minified_css => '#foo{size:5em}.bar{height:40%;width:60%}',
};

our @EXPORT_OK = qw(
    compiled_js minified_js
    compiled_css minified_css
);


1;
