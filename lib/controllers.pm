package controllers;
use strict;
use warnings;
use utf8;

use Data::Dumper;
use JSON::XS;

use config qw($Config);
use tmpl;
use db::stat;
use constant COLUMNS_OFFSET => 1;

my %aliases =
    map {
        my $key = $_;
        my $value = join('', map { substr($_, 0, 1) } split("_", $key) );
        $key => $value
    }
    map { $_ } ( # <- enable modification
        'shared_blks_read', 'shared_blks_dirtied', 'shared_blks_written',
        'local_blks_hit', 'local_blks_read',
        'local_blks_dirtied', 'local_blks_written',
        'temp_blks_read', 'temp_blks_written',
        'blk_read_time', 'blk_write_time'
);

sub setup_ao_columns {
    my $aoColumns = [
        { "mData"       => "_extra",
          "sClass"      => "left",
          "bSortable"   => JSON::XS::false,
        },
    ];
    my $fields = db::stat::get_stats_fields();
    for my $f (@$fields) {
        my %extra_opt = ( $f eq 'query'
            ? ( sWidth => "50%",
                mRender => 'queryRenderFn', # ?
                sClass  => 'left',
            )
            : (sClass => "right")
        );
        push @{ $aoColumns }, {
            sTitle => $aliases{$f} // $f,
            mData  => $f,
            asSorting => ["desc", "asc"],
            %extra_opt,
        };
    }
    return $aoColumns;
}

sub index {
    my $pkg = shift;
    my ($req, $route, $session) = @_;
    my $params = $req->parameters->mixed;

    my $filter = '';
    if ($params->{dbid} or $params->{userid}) {
        $filter = "?dbid=$params->{dbid}&userid=$params->{userid}";
    }
    my $db_name = $route->{db_name};
    my $db_stat = db::stat->new($db_name);

    #print STDERR "session => " . Dumper($session);
# Prepare data
    my $data = {
        users  => $db_stat->users(),
        dbs    => $db_stat->databases(),
        params => $params,
        fields => $db_stat->get_stats_fields(),
        filter => $filter,
        aoColumnsJSON => JSON::XS->new->ascii->pretty->encode(setup_ao_columns()),
        session => $session,
    };

    my @db_links = db::stat::db_links();
    my (@db_list, $db_url);
    for my $db (@db_links) {
        my %db_out = (url => '/', name => $db); # TODO : move to config ?
        if ($db ne 'master') { $db_out{url} = '/' . $db . '/'; }
        if ($db eq $db_name) {
            $db_out{class} = 'active';
            $db_url = $db_out{url};
        }
        push @db_list, \%db_out;
    }
    $data->{db_list} = \@db_list;
    $data->{db_url}  = $db_url;

    my $tmpl = tmpl::init();
    return +{
        code => 200,
        type => "text/html",
        body => $tmpl->render('app.tx', $data),
    };
}

sub stat {
    my $pkg = shift;
    my ($req, $route) = @_;
    my $params = $req->parameters->mixed;
    my $fields = db::stat::get_stats_fields();
    my $db_stat = db::stat->new($route->{db_name});

# prepare params for query
    my @order_by;
    for (sort grep { /^iSortCol_/ } keys %$params) {
        next unless /^iSortCol_(\d+)/;
        my $idx = $params->{$_} - COLUMNS_OFFSET;
        my $direction = $params->{"sSortDir_$1"};
        push @order_by, {
            name => $fields->[$idx],
            direction => $direction,
        };
    }

    my @search;
    if (my $search_raw = $params->{sSearch}) {
        for (split(/\s+/, $search_raw)) {
            next unless /^(!)?(.+)/;
            my ($negative, $word) = ($1, $2);
            next if length $word < 3;

            push @search, { negative => !!$negative, word => $word };
        }
    }
    my $ret_stat = $db_stat->get_stats(
        offset    => $params->{iDisplayStart},
        page_size => $params->{iDisplayLength},
        user_id   => $params->{userid},
        db_id     => $params->{dbid},
        order_by  => \@order_by,
        search    => \@search,
    );

# Prepare data for view
    my %usr = map { $_->{oid} => $_->{rolname} } @{ $db_stat->users() };
    my %db  = map { $_->{oid} => $_->{datname} } @{ $db_stat->databases() };
    for my $item (@{ $ret_stat->{data} }) {
        $item->{avgtime}    = round_float($item->{avgtime}, 5);
        $item->{total_time} = round_float($item->{total_time}, 2);
        $item->{_extra} = qq{<img src="/images/details_open.png" width="20" height="20">};
        $item->{userid} = $usr{ $item->{userid} } // $item->{userid};
        $item->{dbid}   = $db{ $item->{dbid} } // $item->{dbid};
    }
    my $data = {
        iTotalRecords        => $ret_stat->{count},
        iTotalDisplayRecords => $ret_stat->{count},
        aaData               => $ret_stat->{data},
        sEcho                => $params->{sEcho},
    };

    return +{
        code => 200,
        type => "text/json",
        body => encode_json($data),
    };
}

sub round_float {
    my ($num, $places) = @_;
    return pretty_num_tail(sprintf("%.${places}f", $num));
}

sub pretty_num_tail {
    my $num = shift;
    $num=~ s/0+$//;
    $num =~ s/\.$//;
    return $num;
}

1;
