package OAuth2::Client;
use strict;
use warnings;
use utf8;
use base qw(Class::Accessor::Fast);

#use Data::Dumper;
use Encode;
use JSON::XS;
use Params::Check qw(check allow last_error);
use URI;
use URI::Escape;
use LWP::UserAgent; 
use HTTP::Request;
use constant LWP_TIMEOUT => 3;

# TODO : rename api_id -> client_id
my %new_params = (
    base_url      => { required   => 1 },
    # token_url => 'https://accounts.google.com/o/oauth2/token'
    token_url     => { required   => 0 },
    auth_url      => { required   => 0 },
    # api_id => OAUTH2_APP_ID
    api_id        => { required   => 1 },
    # OAUTH2_APP_SECRET
    secret        => { required   => 1 },
    # access_token_path
    redirect_uri  => { required   => 1 },

);
my @accessors = (
    keys %new_params, (
    'access_token',
    #'refresh_token',
    #'token_type',
    #'id_token',

    'expires',
) );
__PACKAGE__->mk_accessors(@accessors);


=pod
=cut
sub new {
    my $class = shift;
    my %opt = @_;
    local $Params::Check::ALLOW_UNKNOWN = 1;
    my $parsed_args = check(\%new_params, \%opt, 0);
    die "Could not parse arguments: " . last_error() unless $parsed_args;

    bless \%opt, $class;
}

# grant_type=authorization_code
sub fetch_access_token {
    my $self = shift;
    my $code = shift;
    my $res  = $self->_fetch_access_token($code);
    $self->access_token( $res->{access_token} );
    $self->expires( $res->{expires_in} // $res->{expires_at} );
    #$self->refresh_token( $res->{refresh_token} );
    #$self->id_token( $res->{id_token} );
    #$self->token_type( $res->{token_type} );
    return $self;
}

sub _fetch_access_token {
    my $self = shift;
    my $code = shift;
    my $url  = $self->token_url;

    my %params = (
        code          => $code,
        client_id     => $self->client_id,
        client_secret => $self->secret,
        redirect_uri  => $self->redirect_uri,
        grant_type    => 'authorization_code',
    );

    my $ua = LWP::UserAgent->new();
    $ua->timeout(LWP_TIMEOUT);
    $ua->default_header('Content-Type' => 'application/x-www-form-urlencoded');

    #print STDERR "post $url => " . Dumper(\%params);
    my $resp = $ua->post($url, \%params);
    unless ($resp->is_success) {
        die "OAuth access token request error => " 
            . $resp->status_line . ": " . $resp->decoded_content;
    }
    #warn  "result => " . $resp->status_line . ": " . $resp->decoded_content;

    my $result = $self->parse_access_token($resp->decoded_content);
    die "ERROR: access token request failed ". $result->{error}
        if exists $result->{error};

    return $result;
}

sub parse_access_token {
    my $self = shift;
    my $content = shift;
    return decode_json($content);
}

sub get    { shift->request(GET => @_)  }

sub post   { shift->request(POST => @_) }

sub request {
    my $self = shift;
    my ($method, $path, $params) = @_;
    $params //= {};
    my $req = $self->make_request_obj($method, $path, $params);
    #print STDERR "REQUEST:\n" . decode('utf-8', $req->as_string) . "\n";

    my $ua = LWP::UserAgent->new();
    $ua->timeout(LWP_TIMEOUT);
    my $resp = $ua->request( $req );
    #print STDERR "RESPONSE:\n" . decode('utf-8', $resp->as_string) . "\n";

    unless ($resp->is_success) {
        die "OAuth query error => " . $resp->status_line;
    }
    return decode_json($resp->decoded_content);
}

sub make_request_obj {
    my $self = shift;
    my ($method, $path, $params) = @_;

    my $uri = URI->new($self->base_url);
    my $full_path = join('/', $uri->path, $path);
    $full_path =~ s{/+}{/}g; # broke https://
    $uri->path($full_path);
    $uri->query_form({ 
        access_token  => $self->access_token,
        client_id     => $self->client_id,
        client_secret => $self->secret,
        redirect_uri  => $self->redirect_uri,
    });

    my $url = $uri->as_string;

    my $req = HTTP::Request->new(uc($method), $url);
    $req->header(Host => $uri->host);
    return $req;
}

sub client_id {
    my $self = shift;
    return $self->api_id;
}

# sub auth_url {}
# sub get_user_info {}
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
    push @pairs, "scope=" . join(',', @{ $opt{scope} });
    my $query = join '&', @pairs;
    my $url   = join('?', $self->auth_url, $query);

    return $url;
}

1;
