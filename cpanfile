requires 'perl',                     '5.010001';
requires 'Cache::Cache',             '1.06';
requires 'CSS::Minifier::XS',        '0.08';
requires 'File::Slurp',              '9999.19';
requires 'JavaScript::Minifier::XS', '0.09';
requires 'Plack';

on 'test' => sub {
    requires 'Test::More',           '0.98';
    requires 'Test::Name::FromLine', '0.010';
};
