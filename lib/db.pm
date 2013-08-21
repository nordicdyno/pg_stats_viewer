package db;
use DBI;

sub new {
    my $class = shift;
    my %opt   = @_;
    bless { %opt }, $class;
}

sub get_dbh {
    my $self = shift;
    my $dbh = $self->{dbh};
    if (!$dbh or !$dbh->ping) {
        $self->{dbh} = $dbh = $self->connect_db();
    }
    return $dbh;
}

sub connect_db {
    my $self = shift;
    my ($user, $passwd) = ($self->{user}, $self->{password});
    my $dsn = _generate_dsn(
        name => $self->{name},
        host => $self->{host},
        port => $self->{port},
    );

    my $dbh = DBI->connect_cached($dsn, $user, $passwd, {
            RaiseError => 1,
            PrintError => 0,
            pg_enable_utf8    => 1,
# DBD::Pg issue: AutoCommit = 1 - don't use implicit BEGIN .. END for readonly requests
            AutoCommit        => 1,
            pg_expand_array   => 0,
            pg_server_prepare => 0,
            HandleError => $self->{exception_cb},
    });
    die "Can't connect to DB (dsn=$dsn): $DBI::errstr\n"
        unless $dbh;
#DBI->trace(1);

    return $dbh;
}

sub _generate_dsn {
    my %args = @_;
    my @dsn = ("dbi:Pg:dbname=" . $args{name});
    push @dsn, "host=" . $args{host} ;
    push @dsn, "port=" . $args{port} ;

    return join(';', @dsn);
}

1;
