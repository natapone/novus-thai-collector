use strict;
use warnings;
use Data::Dumper;

use Test::More tests => 3;
BEGIN { use_ok('novus::thai::collector') };
BEGIN { use_ok('novus::thai::schema') };
BEGIN { use_ok('novus::thai::utils') };

my $config = novus::thai::utils->get_config();
my $schema = novus::thai::schema->connect(
                                $config->{connect_info}[0], 
                                $config->{connect_info}[1], 
                                $config->{connect_info}[2], 
                                $config->{connect_info}[3], 
                                );

my $feed = $schema->resultset('Feed')->find(1);

$feed->fetch("./test");

