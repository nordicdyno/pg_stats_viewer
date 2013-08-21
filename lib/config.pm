package config;
use utf8;
use strict;
use warnings;
use Exporter 'import';
use Data::Dumper;
use Config::IniFiles;

our $Config = {};
our @EXPORT_OK = qw($Config);

my $Dir = 'conf';
sub init {
    my $type = shift;
    my $type_ini_f = join('/', $Dir, "$type.ini");
    my $main_ini_f = join('/', $Dir, "config.ini");
    my $main_ini  = read_ini($main_ini_f);
    #print 'main => ' . Dumper($main_ini);
    my $whole_ini = $main_ini;
    if (-f $type_ini_f) {
        $whole_ini = read_ini($type_ini_f, -import => $main_ini);
    }
    #print 'whole => ' . Dumper($whole_ini);
    $Config = $whole_ini; 
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
