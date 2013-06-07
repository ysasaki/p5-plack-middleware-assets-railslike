requires 'perl',                     '5.010001';
requires 'Cache::Cache',             '1.06';
requires 'CSS::Minifier::XS',        '0.08';
requires 'Digest::SHA1',             '2.13';
requires 'File::Slurp',              '9999.19';
requires 'HTTP::Date',               '6.02';
requires 'JavaScript::Minifier::XS', '0.09';
requires 'Plack';

on 'test' => sub {
    requires 'Test::More',           '0.98';
    requires 'Test::Name::FromLine', '0.010';
    requires 'Test::Time',           '0.04';
};
