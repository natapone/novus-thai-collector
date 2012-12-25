#!/usr/local/bin/perl -w
use lib "/home/dong/src/lib/perl5";
use lib "/home/dong/src/NPC/novus-thai-collector/lib";
use lib "/home/dong/src/NPC/novus-thai-schema/lib";
use lib "/home/dong/src/NPC/novus-thai-utils/lib";

use novus::thai::schema;
use novus::thai::utils;
use Encode;

my $sourcefile = 'thai_stopword.txt';

my $config = novus::thai::utils->get_config();
my $schema = novus::thai::schema->connect(
                                $config->{connect_info}[0], 
                                $config->{connect_info}[1], 
                                $config->{connect_info}[2], 
                                $config->{connect_info}[3], 
                                );

my $keywords = $schema->resultset('Keyword');

open (MYFILE, "./etc/$sourcefile");
while (<MYFILE>) {
    chomp;
    
    if ($_) {
#        my $k = novus::thai::utils->trim($_);
        my $k = decode_utf8($_);
        my $l = length($k);
        my $result = $keywords->update_or_create(
                        {
                            name   => $_,
                            is_stopword => 1,
                            length => $l,
                        }, { key   => 'keyword_name_key' }
        );
        
        print "$_ --> Create ", $result->id, ": ", $result->name, " length = ", $result->length ,"\n";
    }
    
}
close (MYFILE); 
