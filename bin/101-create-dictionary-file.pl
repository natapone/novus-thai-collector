#!/usr/local/bin/perl -w
use lib "/home/dong/src/lib/perl5";
use lib "/home/dong/src/NPC/novus-thai-collector/lib";
use lib "/home/dong/src/NPC/novus-thai-schema/lib";
use lib "/home/dong/src/NPC/novus-thai-utils/lib";

use novus::thai::schema;
use novus::thai::utils;
use Encode;
use Storable;
use Term::ProgressBar;
use Data::Dumper;

my $dict_words = ();
my $dict_file = 'novus_thai_dict.dict';

my $config = novus::thai::utils->get_config();
my $schema = novus::thai::schema->connect(
                                $config->{connect_info}[0], 
                                $config->{connect_info}[1], 
                                $config->{connect_info}[2], 
                                $config->{connect_info}[3], 
                                );

my $keywords = $schema->resultset('Keyword')->search_rs({ 
                                                    active => 1 
                                                },{
#                                                    rows => 100
                                                });

my $dict_count = $keywords->count;
my $maxlength = 0;
my $d_count = 0;
my $progress_bar = Term::ProgressBar->new($dict_count);


while (my $keyword = $keywords->next) {
#    print $keyword->id, ": ", $keyword->name, "    l== ", $keyword->length, "\n";
    
    my $keyword_name = decode_utf8($keyword->name);
#    my $keyword_name = $keyword->name;
    $dict_words->{$keyword_name} = $keyword->id;
    $maxlength =  $keyword->length if ($keyword->length > $maxlength );
    
    
    $d_count++;
#    $progress_bar->update($d_count) if (!($d_count%500) or ($d_count == $dict_count));
    $progress_bar->update($d_count);
}

store(\$dict_words, "./etc/".$dict_file) || die "can't store to $dict_file\n";

print "Dictionary created! ($dict_count) in $dict_file \n";

# update maxlength
my $config_updates = $schema->resultset('Sysconfig')->update_or_create({
                                configname  => 'DICT_MAXLENGTH',
                                configvalue => $maxlength,
                            });

print "Longest keyword = $maxlength  \n";

