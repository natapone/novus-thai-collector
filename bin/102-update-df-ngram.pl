#!/usr/local/bin/perl -w
use strict;
use warnings;
use Data::Dumper;
use Encode;
use Try::Tiny;

use novus::thai::utils;
use novus::thai::schema;
use novus::thai::collector;
use novus::thai::collector::tokenizer;
use novus::thai::collector::ngram;
use Term::ProgressBar;
use Storable;

my $config = novus::thai::utils->get_config();
our $schema = novus::thai::schema->connect(
                                $config->{connect_info}[0], 
                                $config->{connect_info}[1], 
                                $config->{connect_info}[2], 
                                $config->{connect_info}[3], 
                                );

# Init
my $tokenizer = novus::thai::collector::tokenizer->new('debug' => 0 );
my $batch_ngram_count = {};
my $idf_filename = "novus_thai_idf.dict";

# timeslot ==> %Y-%m-%d %H:%M:%S
my $timeslot_start = "2012-01-01 00:00:00";
my $timeslot_end   = "2012-12-31 00:00:00";

my $timestamp_start = novus::thai::utils->string_to_timestamp($timeslot_start);
my $timestamp_end   = novus::thai::utils->string_to_timestamp($timeslot_end);

print "Time start = $timeslot_start ==> $timestamp_start \n";
print "Time end   = $timeslot_end ==> $timestamp_end \n";

my $items = $schema->resultset('Item')->search(
                                { 
                                    timestamp => {
                                        -between => [
                                            $timestamp_start,
                                            $timestamp_end,
                                        ],
                                    }
                                } , {
#                                    rows => 100
                                }
                            );

print "Count = ", $items->count, " items \n";

my $ngram_min_count = 3;
#my $ngram_min_count = $items->count * 0.0005;
#$ngram_min_count = sprintf("%0d", $ngram_min_count);
#$ngram_min_count =2 if ($ngram_min_count <= 0);
print "min_count = $ngram_min_count \n";

print "Word break ...\n";
my $progress_bar = Term::ProgressBar->new($items->count);
my $i_count = 0;

# Count only 1 if term occur in ducument
while (my $item = $items->next) {
    my $context = $item->title;
    $context .= " " . $item->description if ($item->description);
    
    my $engine_NG = novus::thai::collector::ngram->new(
                                                windowsize => 7,
                                                min_windowsize => 2,
                                                min_count  => 1,
                                                );
    
    my $tokens = $tokenizer->tokenize($context);
    my $token_keywords = $tokens->{'token'}->{'id'};
    
    foreach (@$token_keywords) {
        $engine_NG->feed_tokens($_);
    }
    
    my $ngrams = $engine_NG->return_ngrams();
    
    my $item_ngram_count = {};
    if ($ngrams) {
        foreach my $gram ( 
            sort { $ngrams->{$b} <=> $ngrams->{$a} }
            keys %$ngrams ) {
            
            $item_ngram_count->{$gram} = 1;
        }
        
        # Add list of ngram
        foreach my $item_ngram (keys %$item_ngram_count) {
#            my $ngram_keyword = $tokenizer->id_to_keyword($item_ngram);
#            print "***", $item_ngram , " = ", encode_utf8($ngram_keyword) , " ===> ", $item_ngram_count->{$item_ngram} ,"\n";
            
            $batch_ngram_count = _add_to_hash($batch_ngram_count, $item_ngram);
        }
        
    }
    
    $i_count++;
    $progress_bar->update($i_count);
}

my $ngram_insert_count = keys %$batch_ngram_count;
print "Write Ngram to DB or idf file... $ngram_insert_count \n";
$progress_bar = Term::ProgressBar->new ({count => $ngram_insert_count});

# delete old Ngram
#$schema->resultset('Ngram')->delete();

# temp hash to store id and idf value
my $ingramid_idf = {};
$i_count = 0;

foreach my $ngram ( 
#    sort { $batch_ngram_count->{$b} <=> $batch_ngram_count->{$a} }
    keys %$batch_ngram_count ) {
    
    my @gram = split(' ', $ngram);
    my $gram_count = @gram;
    
    my $ngram_keyword = $tokenizer->id_to_keyword($ngram);
    
#    print "$ngram ++++ ", encode_utf8($ngram_keyword) , " ===> ", $batch_ngram_count->{$ngram} ,
#     " gram count= ", $gram_count,"\n" if ($batch_ngram_count->{$ngram} > $ngram_min_count);
    
    if ($batch_ngram_count->{$ngram} >= $ngram_min_count) {
        # update DB
#        my $add_ngram_id = $schema->resultset('Ngram')->create(
#                            {
#                                ngramid => $ngram,
#                                term    => $ngram_keyword,
#                                document_frequency => $batch_ngram_count->{$ngram},
#                                ngram_length       => $gram_count,
#                            }, { key    => 'ngram_term_key' }
#                        );
                        
        # prepare idf hash
        my $idf = $items->count / $batch_ngram_count->{$ngram};
        $idf    = log($idf);
        $ingramid_idf->{$ngram} = $idf;
        
#        print print "$ngram (", encode_utf8($ngram_keyword) , ")   => ", $idf, "\n";
        
    }
    
    $i_count++;
    $progress_bar->update($i_count);
}

#End process
if ($ingramid_idf) {
    store(\$ingramid_idf, "./etc/".$idf_filename) || die "can't store to $idf_filename\n";
}


if ($batch_ngram_count) {
    my $lastcal_update = $schema->resultset('Sysconfig')->update_or_create( { 
                                configname => 'LASTCAL_DF_NGRAM',
                                configvalue => $timestamp_end,
                            });
                            
    print "Update 'LASTCAL_DF_NGRAM' = $timestamp_end \n";
}



sub _add_to_hash {
    my ($hash, $new_key) = @_;
    
    if ($hash->{$new_key}) {
        $hash->{$new_key}++;
    } else {
        $hash->{$new_key} = 1;
    }
    
    return $hash;
}
