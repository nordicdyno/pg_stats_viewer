package tmpl;
use strict;
use warnings;
use utf8;
use Data::Dumper;
use Text::Xslate;

my $tx;
sub init {
    my $class = shift;
    my %opt = @_;
    return $tx if $tx;

    $tx = Text::Xslate->new(
        path => 'tmpl',
        suffix => 'tx',
        function => {
            round_time => sub { int $_[0] },
            sort_link => sub {
                my $arr = shift;
                my ($params, $href_opt) = @$arr;
                my ($title, $key, $alt_title) = @{ $href_opt || [] };
                $key //= $title;
                $alt_title //= $title;
                my $direction = "asc";
                my $url = "?order_by=$key&direction=$direction";

                for my $name (keys %{ $params || {} }) {
                    next if $name eq 'order_by';
                    next if $name eq 'direction';
                    $url = $url . "&" . $name . "=" . $params->{$name};
                }
                return "<a href=\"$url\" title=\"$alt_title\">$title</a>";
            },
        },
    );

    return $tx;
}
init();

1;
