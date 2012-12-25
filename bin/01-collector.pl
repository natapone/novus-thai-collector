#!/usr/local/bin/perl -w
use lib "/home/dong/src/lib/perl5";
use lib "/home/dong/src/NPC/novus-thai-collector/lib";
use lib "/home/dong/src/NPC/novus-thai-schema/lib";
use lib "/home/dong/src/NPC/novus-thai-utils/lib";

use strict;
use warnings;

use novus::thai::collector;
use novus::thai::schema;
use novus::thai::utils;

use Data::Dumper;

my $config = novus::thai::utils->get_config();
my $schema = novus::thai::schema->connect(
                                $config->{connect_info}[0], 
                                $config->{connect_info}[1], 
                                $config->{connect_info}[2], 
                                $config->{connect_info}[3], 
                                );

#my $feed = $schema->resultset('Feed')->find(1);


my $feeds = $schema->resultset('Feed')->search(
#    {
#        id => 128
#    }
);

print "Read feeds\n";

while (my $feed = $feeds->next) {
    
    print "ID:", $feed->id, ' ', $feed->link;
    print " target = ", $feed->fetch(), "\n";
    
}




