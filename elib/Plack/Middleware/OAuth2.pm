package Plack::Middleware::OAuth2;

use strict;
use warnings;
use parent qw/Plack::Middleware/;

use Plack::Response;
use Plack::Request;
use JSON::XS;

use Plack::Util::Accessor qw(
    client_id
    client_secret
    redirect_uri
    provider
    valid_users

    client
);

# call only once when run app
sub prepare_app {
    my $self = shift;

    die 'requires client_id'     unless $self->client_id;
    die 'requires client_secret' unless $self->client_secret;
    die 'requires redirect_uri'  unless $self->redirect_uri;
    die 'requires provider'      unless $self->provider;

    die 'requires valid_users'   unless $self->valid_users;
    die 'requires get method on valid_users' unless $self->valid_users->can('get');

    my $client = $self->create_client();
    return;
}

sub create_client {
    my $self = shift;
    my @lib = ('OAuth2', 'Client', $self->provider);
    require join('/', @lib) . '.pm';

    my $provider  = join('::', @lib);
    my $client = $provider->new(
        api_id  => $self->client_id,
        secret  => $self->client_secret,
        redirect_uri  => $self->redirect_uri,
    );
    $self->client($client);
}

# call every time when we communicate with app
sub call {
    my ($self, $env) = @_;
    my $path = $env->{PATH_INFO};
    my $provider = lc($self->provider);

# get from config for providers ?
    for ($path) {
        if (m{^/oauth2/$provider/?$})         { return $self->oauth_page() }
        if (m{^/oauth2/$provider/callback/?}) { return $self->oauth_callback($env) }
        if (m{^/oauth2/$provider/exit/?})     { return $self->oauth_exit($env) }
        return $self->default($env);
    }
}


use Data::Dumper;
my %CFG = (
    VK => {
        name_field => 'screen_name',
        id_field   => 'uid',
        scope      => ['photo', 'offline'],
    },
    Facebook => {
        name_field => 'name',
        id_field   => 'username',
        scope      => [ 'user_about_me' ],
    },
    Google   => {
        name_field => 'name',
        id_field   => 'email',
        scope => [ map {
            "https://www.googleapis.com/auth/userinfo.$_" } qw(email profile)
        ],
    },
);
$CFG{Google}{photo_cb} = sub {
    my ($client, $info, $size) = @_;
    return +{} unless $info->{picture};
    return +{
        link => $info->{picture} . '?sz=42',
        width => $size, height => $size 
    };
};
$CFG{Facebook}{photo_cb} = sub { 
    my ($client, $info, $size) = @_;
    return +{
        link  => 'http://graph.facebook.com/' . $info->{id} . '/picture',
        width => 46, height => 46,
    }; 
};
$CFG{VK}{photo_cb}  = sub {
    my ($client, $info, $size) = @_; 
    return +{
        link  => $info->{photo},
        width => 46, height => 46,
    }; 
};
# TODO  Twitter

sub oauth_page {
    my ($self, $env) = @_;

    # save url, which user click before auth
    my $req_uri = $env->{REQUEST_URI};

    if ( not $env =~ m{^/oauth2/} ) {
        $env->{'psgix.session'}->{redirect_url} = $req_uri; 
    }

    my $provider = $self->provider;
    my $url = $self->client->make_auth_query(scope => $CFG{$provider}{scope});

    my $html = <<"LOGIN";
<html>
<head><title>Login page</title></head>
<body>
<div style="text-align: center; font-size: 80%; font-family: Arial, sans-serif">
    <p><a href="$url">Log in</a> with your $provider account</p>
    <p style="margin-top: 3em">
    For access, contact with <a href="">administrator</a>.
    </p>
</div>
</body>
</html>
LOGIN

    return [200, [ 'Content-Type' => 'text/html' ], [ $html ] ];
}

# check access token/id, then return control to app
sub oauth_admin {
    my ($self, $env) = @_;

    # go to login page in we havent access_token
    return $self->oauth_page() if not $self->_is_access_token_exist($env);
    # second value type = 1 means only admin
    return $self->oauth_page() if not $self->_is_id_allow($env, 1);

    # return to wrapped app
    return $self->app->($env);
}

# process callback
sub oauth_callback {
    my $self = shift;
    my ($env) = @_;
    my $req          = Plack::Request->new($env);
    my $code         = $req->param("code") || '';
    my $session      = $env->{'psgix.session'};
    my $client = $self->client;
    my $provider = $self->provider;
    my $cfg = $CFG{$provider};

    # TODO: check fetch result
    $client->fetch_access_token($code);
    my $user_info    = $client->get_user_info();
    my $id           = $user_info->{ $cfg->{id_field} };

    #print Dumper($user_info);

    # if email in allow list come back to main application
    my $user_cfg = $self->valid_users->get($id);
    if ($user_cfg) {
        $session->{user}{photo} = $cfg->{photo_cb}->($client, $user_info, 42);
        $session->{user}{name}  = $user_info->{ $cfg->{name_field} } // '???';
        $session->{oauth_access_token} = $client->access_token;
        $session->{oauth_id}        = $id;
        $session->{provider}        = lc $provider;

        # restore old redirect url
        my $redirect_url  = $env->{'psgix.session'}->{redirect_url} || '/'; 

        # redirect
        my $res = Plack::Response->new;
        $res->redirect($redirect_url);

        return $res->finalize;
    }

    my $contact_email = "-";
    return [
        401, 
        [ 'Content-Type' => 'text/html' ], 
        [ '<h3>Authorization required! '.$id.qq{ isnt allowed! Please contact us by email: $contact_email</h3> <br/> <a href="/">Sign in</a>} ] 
    ];
}

sub oauth_exit {
    my ($self, $env) = @_;
    $env->{'psgix.session'}->{oauth_access_token} = undef;
    $env->{'psgix.session'}->{oauth_id}        = undef;

    my $res = Plack::Response->new;
    $res->redirect('/');
    return $res->finalize;
}

# check access token/id, then return control to app
sub default {
    my ($self, $env) = @_;

    # go to login page in we havent access_token
    return $self->oauth_page($env) if not $self->_is_access_token_exist($env);
    return $self->oauth_page($env) if not $self->_is_id_allow($env);
    return $self->app->($env);
}

sub _is_access_token_exist {
    my ($self, $env) = @_;
    my $session      = $env->{'psgix.session'};
    my $access_token = $session->{'oauth_access_token'};
    return $access_token ? 1 : 0;
}

sub _is_id_allow {
    my ($self, $env) = @_;
    my $session = $env->{'psgix.session'};
    my $id   = $session->{'oauth_id'};
    return $self->valid_users->get($id) ? 1 : 0;
}

1;
