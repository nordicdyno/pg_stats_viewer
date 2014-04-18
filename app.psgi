#!/usr/bin/env perl
#
use strict;
use warnings;
use feature 'say';
BEGIN {
   if (-d "local/lib/perl5") { use lib "local/lib/perl5" }
};
use Plack::Request;
use Plack::Builder;
use Router::Simple;
use Encode;
#use Data::Dumper;
#use Data::Printer;
use Plack::Session::Store::Cache;
use CHI;

use lib './lib';
use lib './elib';

use users;
use config qw($Config $ConfigH);
config::init($ENV{PLACK_ENV} // 'deployment' );

my $Router  = Router::Simple->new();
my @routes = (
    #['/favicon.ico', {}],
    ['/',                    {controller => 'controllers', action => 'index'}],
    ['/{db_name}/',          {controller => 'controllers', action => 'index'}],

    ['/stat.json',           {controller => 'controllers', action => 'stat'}],
    ['/{db_name}/stat.json', {controller => 'controllers', action => 'stat'}],
);
for my $r (@routes) {
    $Router->connect(@$r);
    my $cntrl = $r->[1]->{controller};
    if (defined $cntrl) {
        $cntrl = "$cntrl.pm";
        next if $INC{$cntrl};
        require $cntrl;
    }
}

# TODO : move routes to config?
my $app = sub {
    my $env = shift; # PSGI env
    my $session = $env->{'psgix.session'};

    my $route = $Router->match($env);
    unless ($route) {
        return [404, [], ['not found']];
    }

    my $req = Plack::Request->new($env);
    my $path_info = $req->path_info;
    my $query     = $req->param('query');

    my $data;
    my @controller_opt = ($req, $route, $session);
    $route->{db_name} //= $Config->val('global', 'defaultDB');
    $data = $route->{cb}->(@controller_opt) if $route->{cb};
    if (my $ctrl = $route->{controller}) {
        no strict 'refs';
        my $action = $route->{action};
        $data = $ctrl->$action(@controller_opt);
    }

    my $res = $req->new_response($data->{code}); # new Plack::Response
    $res->content_type($data->{type});
    $res->body(encode('UTF-8', $data->{body}));

    return $res->finalize;
};

# Base middlewares:
my $builder = Plack::Builder->new;
$builder->add_middleware('Static',
    path => qr{^/(favicon.ico|(images|js|css|favicon)/)},
    root => './static/',
);
$builder->add_middleware("HTTPExceptions", rethrow => 1);

# Add user defined middlewares
my @m = $Config->GroupMembers('MIDDLEWARE');
for my $gr_m (@m) {
    my $midd_name = [ split(' ', $gr_m) ]->[1];
    my $midd_cfg = $ConfigH->{$gr_m};
    next unless $midd_cfg->{enabled};

    my %midd_opt = map { $_ => parse_middleware_value($midd_cfg->{$_})}
                   grep { $_ ne 'enabled' }
                   keys %$midd_cfg;
    $builder->add_middleware($midd_name, %midd_opt);
}

# Extra middlewares
# Auth & sessions
OAUTH_INIT: {
    my $provider = $ConfigH->{global}{oauth};
    last OAUTH_INIT unless $provider;
    my $conf = $ConfigH->{"oauth $provider"};
    last OAUTH_INIT unless $conf;

    my $storage = $Config->{session}{store} || 'FastMmap'; # requres Cache::FastMmap
    my $cache = CHI->new(driver => $storage);
    my %session_opt = (store => Plack::Session::Store::Cache->new(cache => $cache));
    $builder->add_middleware('Session', %session_opt);

    my $users = users->new(users::parse_users($conf->{'valid_users'}));
    my %oauth_opt = map { $_ => $conf->{$_} }
        qw(provider client_id client_secret redirect_uri);
    $oauth_opt{valid_users} = $users;
    $oauth_opt{pages_templator} = \&oauth_tmpl;
    $builder->add_middleware('OAuth2', %oauth_opt);
}

return $builder->wrap($app);

sub oauth_tmpl {
    my $tx = tmpl::init();
    my ($page, $ctx) = @_;
    $ctx->{test} = ":D"; # for debug
    $tx->render($page.".tx", $ctx)
}

sub parse_middleware_value {
    my $val = shift;
    if ($val =~ /^\[(.*)\]$/) {
        my @array = map { s/\s+//g; $_ } split(', ', $1);
        $val = \@array;
    }
    return $val;
}
