package OAuth2::Client::VK;
use strict;
use warnings;
use utf8;
use parent qw(OAuth2::Client);
use HTTP::Request;
use URI;

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(
        token_url       => 'https://oauth.vk.com/access_token',
        base_url        => 'https://api.vk.com/method/',
        auth_url        => 'https://oauth.vk.com/authorize',
        @_,
    );
    return $self;
}

#use Data::Dumper;
sub fetch_access_token {
    my $self = shift;
    my $code = shift;
    my $res  = $self->_fetch_access_token($code);
    $self->access_token($res->{access_token});
    #$self->refresh_token( $res->{refresh_token} );
    $self->expires($res->{expires_in});
    #$self->id_token( $res->{id_token} );
    #$self->token_type( $res->{token_type} );
    $self->{_user_id} = $res->{user_id};

    #print "VK res => " . Dumper($res);

    return $self;
}

sub make_request_obj {
    my $self = shift;
    my ($method, $path, $params) = @_;

    my $uri = URI->new($self->base_url);
    my $full_path = join('/', $uri->path, $path);
    $full_path =~ s{/+}{/}g;
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
    my $user = $self->get('users.get', {
        'uids' => $self->{_user_id},
        'fields' => join(',', qw(
            uid first_name last_name nickname screen_name 
            birthdate city country timezone photo)),
    } );
    return unless $user;
    return unless $user->{response};
    return if ref $user->{response} ne 'ARRAY';
    return if @{$user->{response}} < 1;
    return $user->{response}->[0];
}

1;
