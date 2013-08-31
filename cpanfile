requires 'Config::IniFiles';
requires 'Plack';
requires 'Plack::Request';
requires 'Router::Simple';
requires 'HTTP::Exception';
requires 'JSON::XS';
requires 'Text::Xslate';
requires 'DBD::Pg';
requires 'Starman';

# OAuth2 support:
requires 'Plack::Session::Store::Cache';
requires 'CHI';
requires 'Cache::FastMmap';

# OAuth libs (move to CPAN)
requires 'LWP::UserAgent';
requires 'LWP::Protocol::https';
requires 'HTTP::Request';
requires 'URI';
requires 'URI::Escape';
requires 'Params::Check';
#requires 'JSON::XS';
