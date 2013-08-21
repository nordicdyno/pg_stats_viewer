#!/usr/bin/env perl
#
use strict;
use warnings;
use Plack::Request;
use Plack::Builder;
use Router::Simple;
use Encode;
use Data::Dumper;
use lib './lib';
use config qw($Config);

config::init($ENV{PLACK_ENV} // 'deployment' );

my $Router  = Router::Simple->new();
my @routes = (
    ['/favicon.ico', {}],
    ['/', {controller => 'controllers', action => 'index'}],
    ['/{db_name}/', {controller => 'controllers', action => 'index'}],

    ['/stat.json', {controller => 'controllers', action => 'stat'}],
    ['/{db_name}/stat.json', {controller => 'controllers', action => 'stat'}],
);
for my $r (@routes) {
    $Router->connect(@$r);
    my $cntrl = $r->[1]->{controller};
    #print STDERR "check $cntrl\n";
    if (defined $cntrl) {
        $cntrl = "$cntrl.pm";
        next if $INC{$cntrl};
        require $cntrl;
        #print "load controller '$cntrl'";
    }
}

# TODO : move to config
my $app = sub {
    my $env = shift; # PSGI env

    my $route = $Router->match($env);
    unless ($route) {
        return [404, [], ['not found']];
    }

    my $req = Plack::Request->new($env);
    my $path_info = $req->path_info;
    my $query     = $req->param('query');

    my $data;
    my @controller_opt = ($req, $route);
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

return builder {
    enable 'Static',
        path => qr{^/(favicon.ico|(images|js|css|favicon)/)}, root => './static/'
    ;
    enable "HTTPExceptions", rethrow => 1;
    # enable 'Debug', panels => [ qw(Environment Response Memory Timer) ];
    # enable 'StackTrace'; # <-- added automatically by Dev environment
    # enable 'BetterStackTrace';
    # enable 'REPL';
    $app;
};

# Plack::Middleware::Delay
# HTML::Mason::PSGIHandler
# ? Plack::App::Cascade 
# ? Plack::Middleware::Throttle

##############################################################
##############################################################

