package config;
use utf8;
use strict;
use warnings;
use Exporter 'import';
use Data::Dumper;
use Config::IniFiles;

our $Config  = {};
our $ConfigH = {};
our @EXPORT_OK = qw($Config $ConfigH);

my $Dir = $ENV{"CONFIG_DIR"} // 'conf';
sub init {
    my $type = shift;
    my $main_ini_f = join('/', $Dir, "config.ini");
    my $main_ini  = read_ini($main_ini_f);
    my $whole_ini = $main_ini;
    if ($type) {
        my $type_ini_f = join('/', $Dir, "$type.ini");
        if (-f $type_ini_f) {
            $whole_ini = read_ini($type_ini_f, -import => $main_ini);
        }
    }
    $Config = $whole_ini;
    $ConfigH = $Config->{v};
=pod
    for my $sec ($Config->Sections()) {
        for my $p ($Config->Parameters($sec)) {
            $ConfigH->{$sec}{$p} = $Config->val($sec, $p);
        }
    }
=cut
}

sub read_ini {
    my $file = shift;
    my %opt  = @_;
    my $ini  = Config::IniFiles->new(-allowempty => 1, -file => $file, %opt)
        or die "Can't read config file $file\n"
            . join("\n", map {"\t$_" } @Config::IniFiles::errors);
    return $ini;
}

1;
