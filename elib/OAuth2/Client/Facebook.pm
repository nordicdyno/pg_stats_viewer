package OAuth2::Client::Facebook;
use strict;
use warnings;
use utf8;
use parent qw(OAuth2::Client);
use HTTP::Request;
use URI;

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(
        base_url  => 'https://graph.facebook.com/',
        token_url => 'https://graph.facebook.com/oauth/access_token',
        auth_url  => 'https://www.facebook.com/dialog/oauth',
        @_,
    );
    return $self;
}

sub parse_access_token {
    my $self = shift;
    my $content = shift;
    my %pairs = map {
        /^(.*?)=(.*)/ ? ($1 => $2) : ()
    } split('&', $content);
    $pairs{expires_at} = delete $pairs{expires};
    return \%pairs;
}

sub make_request_obj {
    my $self = shift;
    my ($method, $path, $params) = @_;

    my $uri = URI->new($self->base_url);
    my $full_path = join('/', $uri->path, $path);
    $full_path =~ s{/+}{/}g; # broke https://
    $uri->path($full_path);
    $uri->query_form({ 
        %$params,
        access_token  => $self->access_token,
    });

    my $url = $uri->as_string;

    my $req = HTTP::Request->new(uc($method), $url);
    $req->header(Host => $uri->host);
    return $req;
} 

sub get_user_info {
    my $self = shift;
    my $user = $self->get('me', @_);
    return unless $user;

    #$self->user_id($user->{id});
    return $user;
}


1;
