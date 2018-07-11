package users;
use strict;
use warnings;

sub new {
    my $class = shift;
    my %users_table = @_;
    return bless \%users_table, $class;
}

sub get {
    my $self = shift;
    my $id   = shift;
    return if not defined $id;
    return $self->{$id};
}

sub parse_users {
    my $str = shift;
    my %users = map {
        s/\s+//g;
        $_ => 1
    } split(',', $str);
    return %users;
}

1;
