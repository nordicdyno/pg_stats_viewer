package db::stat;
use strict;
use warnings;
use utf8;
use HTTP::Exception;
use db;
use config qw($Config $ConfigH);

my %db_poll; 
my @db_links;

sub init {
    for my $gm ($Config->GroupMembers('db')) {
        my @parts = split(/\s+/, $gm);
        my $db_name = $parts[1];
        push @db_links, $db_name;

        my $db_conf = $ConfigH->{$gm};
        my $exception_cb = sub { 
            my $err = shift;
            HTTP::Exception->throw(500, status_message => "'$db_name' DB error ($err)") 
        };
        $db_poll{$db_name} = db->new(
            %{ $db_conf },
            db_name      => $db_name,
            exception_cb => $exception_cb,
        );
    }
}

my %obj_poll;
sub new {
    my $class = shift;
    my $db_name = shift;
    init() unless keys %db_poll;
    my $obj = $obj_poll{$db_name} // bless { db => $db_poll{$db_name} }, $class;
    return $obj;
}

sub db_links {
    return @db_links;
}

sub users {
    my $self = shift;
    my $users = $self->{users} // $self->select_aref(
        "SELECT oid, rolname FROM pg_authid ORDER BY rolname"
    );
    return $users;
}

sub databases {
    my $self = shift;
    my $databases = $self->{databases} // $self->select_aref(
        "SELECT oid, datname FROM pg_database ORDER BY datname"
    );
    return $databases;
}

sub select_aref {
    my $self = shift;
    my ($query) = @_;
    my $dbh = $self->{db}->get_dbh();
    return $dbh->selectall_arrayref($query, { Slice => {} });
}

sub _stats_query {
    my %opt = (
        user_id  => undef,
        db_id    => undef,
        @_
    );

    my @where;
    for (qw(user_id db_id)) {
        next unless $opt{$_};
        my $name = $_ =~ s/_//gr;
        push @where, "$name = $opt{$_}";
    }

    if ($opt{search} && @{$opt{search}}) {
        for (@{$opt{search}}) {
            push @where, "query " . ($_->{negative} ? "NOT " : "") . "LIKE '%$_->{word}%'";
        }
    }

    my $query = " FROM pg_stat_statements";
    $query .= " WHERE " . join(" AND ", @where) if @where;
    return $query;
}

sub fields_cfg {
    my @f = (
        qw( userid dbid query ),
        'avgtime',
        'calls',
        'total_time',
        'rows',
        'rows_per_call',
        'shared_blks_hit',
        'shared_blks_read',
        'shared_blks_hit_percent',
        'shared_blks_dirtied',
        'shared_blks_written',
        'local_blks_hit',
        'local_blks_read',
        'local_blks_dirtied',
        'local_blks_written',
        'temp_blks_read',
        'temp_blks_written',
        'blk_read_time',
        'blk_write_time'
    );
    my @ret;
    for (@f) {
        my $conf = { name => $_ };
        if ($_ eq 'avgtime') {
            $conf->{select} = "COALESCE(total_time / NULLIF(calls,0), 0)";
        }
        if ($_ eq 'rows_per_call') {
            $conf->{select} = "COALESCE(rows / NULLIF(calls,0), 0)";
        }
        if ($_ eq 'shared_blks_hit_percent') {
            $conf->{select} = "100.0*shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0)";
        }
        push @ret, $conf;
    }
    return @ret;
}

sub get_stats_fields {
    my $f = [ map { $_->{name} } fields_cfg() ];
    return $f;
}

sub get_stats {
    my $self = shift;
    my %opt = (
        order_by => undef,
        user_id  => undef,
        db_id    => undef,
        offset   => undef,
        page     => 1,
        search   => undef,
        @_
    );

    my %q_opt = map { $_ => $opt{$_} } qw(user_id db_id search);

    my $limit  = $opt{page_size} || 10;
    my $offset = $opt{offset};
    if (not defined $offset) {
        my $page = $opt{page} || 1;
        $offset = ($page - 1) * $limit;
    }

    my $count_query  = "SELECT count(1)" . _stats_query(%q_opt);
    my @fields;
    for (fields_cfg()) {
        my $chunk = $_->{select} ? "$_->{select} AS $_->{name}" : $_->{name};
        push @fields, $chunk;
    }
    my $select_query = "SELECT " . join(", ", @fields) . _stats_query(%q_opt);
    if ($opt{order_by} && @{$opt{order_by}}) { 
        $select_query .= " ORDER BY " 
            . join(",", map { 
                $_->{name} . (lc $_->{direction} eq 'desc' ? ' desc' : '');
            } @{$opt{order_by}});
    }
    $select_query .= " LIMIT $limit OFFSET $offset";

    my $ffields = join (', ',
        map { "slct.$_" }
        grep {!/userid|dbid/}
        @{ get_stats_fields() }
    );

    my $dbh = $self->{db}->get_dbh();
    my @counts = $dbh->selectrow_array($count_query);

    my $count = @counts ? $counts[0] : 0;
    my $sth = $dbh->prepare($select_query);
    $sth->execute;
    my $data = $sth->fetchall_arrayref({});
    return {
        data => $data,
        count => $count,
        fields => $sth->{NAME},
    };
}

1;
