package OAuth2::Client::Google;
use strict;
use warnings;
use utf8;
use parent 'OAuth2::Client';
use HTTP::Request;
use URI;
use URI::Escape;

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(
        auth_url  => 'https://accounts.google.com/o/oauth2/auth',
        token_url => 'https://accounts.google.com/o/oauth2/token',
        base_url  => 'https://www.googleapis.com/oauth2/v2/',
        @_,
    );
    return $self;
}

sub make_request_obj {
    my $self = shift;
    my ($method, $path, $params) = @_;

    my $auth_header = join(" ", (
        "Bearer",
        $self->access_token,
    ));

    my $uri = URI->new($self->base_url);
    my $full_path = join('/', $uri->path, $path);
    $full_path =~ s{/+}{/}g;
    $uri->path($full_path);
    $uri->query_form({ %$params, });

    my $url = $uri->as_string;

    my $req = HTTP::Request->new(uc($method), $url);
    $req->header(Host => $uri->host);
    $req->header(Authorization => $auth_header);
    return $req;
} 

sub get_user_info {
    my $self = shift;
    my $user = $self->get('userinfo');
    return unless $user;

    return $user;
}

sub make_auth_query {
    my $self = shift;
    my %opt  = @_;

    my %p = (
        client_id     => $self->api_id, 
        response_type => 'code',
        redirect_uri  => $self->redirect_uri, 
    );
    $p{access_type} = "offline";

    my @pairs;
    for my $key (keys %p) {
        push @pairs, join("=", $key, uri_escape($p{$key}));
    }
    push @pairs, "scope=" . join('+', @{ $opt{scope} });
    my $query = join '&', @pairs;
    my $url   = join('?', $self->auth_url, $query);

    return $url;
}

1;
