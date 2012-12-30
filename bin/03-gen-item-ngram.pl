#!/usr/local/bin/perl -w
use lib "/home/dong/src/lib/perl5";
use lib "/home/dong/src/NPC/novus-thai-collector/lib";
use lib "/home/dong/src/NPC/novus-thai-schema/lib";
use lib "/home/dong/src/NPC/novus-thai-utils/lib";

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

my $config = novus::thai::utils->get_config();
our $schema = novus::thai::schema->connect(
                                $config->{connect_info}[0], 
                                $config->{connect_info}[1], 
                                $config->{connect_info}[2], 
                                $config->{connect_info}[3], 
                                );

# Init
my $tokenizer = novus::thai::collector::tokenizer->new('debug' => 0 );
#my $engine_NG = novus::thai::collector::ngram->new(
#                                                windowsize => 7,
#                                                min_windowsize => 2,
#                                                min_count  => 2,
#                                                );

# timeslot ==> %Y-%m-%d %H:%M:%S
my $timeslot_start = "2012-12-25 00:00:00";
my $timeslot_end   = "2012-12-25 23:59:00";

my $timestamp_start = novus::thai::utils->string_to_timestamp($timeslot_start);
my $timestamp_end   = novus::thai::utils->string_to_timestamp($timeslot_end);

print "Time start = $timeslot_start ==> $timestamp_start \n";
print "Time end   = $timeslot_end ==> $timestamp_end \n";

# get Keyphrase of category IT
my $category = $schema->resultset('Category')->find(2);
my $feeds    = $category->feeds();

# observe
my $batch_ngram_item  = {};
my $batch_ngram_count = {};
my $batch_gram_count  = {};
my $batch_count_doc   = 0;

while (my $feed = $feeds->next) {
    print $feed->id, ": ", $feed->title, " link == ", $feed->link, "\n" ;
    
    my $items = $schema->resultset('Item')->search(
                                { 
                                    feedid    => $feed->id,
                                    timestamp => {
                                        -between => [
                                            $timestamp_start,
                                            $timestamp_end,
                                        ],
                                    }
                                } , {}
    );
    
    while (my $item = $items->next) {
        print "    Item ", $item->id, ": ", $item->title, " @ ", $item->pubdate, "\n";
#        print "       cat : ", $item->category, "\n";
#        print "       desc: ", $item->description, "\n";
        
        my $engine_NG = novus::thai::collector::ngram->new(
                                                windowsize => 7,
                                                min_windowsize => 2,
                                                min_count  => 1,
                                                );
        
        $batch_count_doc++;
        my $context = $item->title . " " . $item->description;
        my $tokens = $tokenizer->tokenize($context);
        my $token_keywords = $tokens->{'token'}->{'keyword'};
        my $vsm_keywords   = $tokens->{'vsm'}->{'keyword'};
        
        # Add list of gram
        foreach my $vsm_key (keys %$vsm_keywords) {
#            print "~~~~", encode_utf8($vsm_key), "\n";
            $batch_gram_count = _add_to_hash($batch_gram_count, $vsm_key);
        }
        
        foreach (@$token_keywords) {
#            print "-", encode_utf8($_);
            $engine_NG->feed_tokens($_);
        }
        
        my $ngrams = $engine_NG->return_ngrams();
        
        my $item_ngram_count = {};
        if ($ngrams) {
            # Clean up ngram in item
##            my $in_del = $schema->resultset('ItemNgram')->search( {itemid => $item->id} );
##            $in_del->delete_all() if ($in_del);
            
            foreach my $gram ( 
            sort { $ngrams->{$b} <=> $ngrams->{$a} }
            keys %$ngrams ) {
                
#                my @gram_size_ = split(' ', $gram);
#                my $gram_size = @gram_size_;
                
#                print "    ", encode_utf8($gram) , " ===> ", $ngrams->{$gram} ,"\n";
#                print "    ID=", $item->id, " ngram=", encode_utf8($gram), " l=", $gram_size, " c=", $ngrams->{$gram} ,"\n";
                
                # insert to table ItemNgram
##                my $in_insrt = $schema->resultset('ItemNgram')->create({
##                                    itemid          => $item->id,
##                                    ngram_by_id     => $gram,
##                                    ngram_length    => $gram_size,
##                                    ngram_count     => $ngrams->{$gram},
##                                });
                
                # Add list of ngram
#                $batch_ngram_count = _add_to_hash($batch_ngram_count, $gram);
                $item_ngram_count->{$gram} = 1;
#                foreach my $item_ngram (keys %$item_ngram_count) {
#    #                $batch_gram_count = _add_to_hash($batch_gram_count, $vsm_key);
#                    print "~~~", encode_utf8($item_ngram) , " ===> ", $item_ngram_count->{$item_ngram} ,"\n";
#                    
#                }
#                print "~~~XXX~~~\n";
                
#                # Add list of gram
#                my @tmp_grams = split(' ', $gram);
#                foreach(@tmp_grams) {
##                    print "     -- ", decode_utf8($_), "\n";
#                    $batch_gram_count = _add_to_hash($batch_gram_count, $_);
#                    
#                }
                
#                exit;
            }
            
            # Add list of ngram
            foreach my $item_ngram (keys %$item_ngram_count) {
#                $batch_gram_count = _add_to_hash($batch_gram_count, $vsm_key);
#                print "***", encode_utf8($item_ngram) , " ===> ", $item_ngram_count->{$item_ngram} ,"\n";
                
                $batch_ngram_count = _add_to_hash($batch_ngram_count, $item_ngram);
            }
#            exit;
#            foreach my $gram ( 
#                sort { $batch_ngram_count->{$b} <=> $batch_ngram_count->{$a} }
#                keys %$batch_ngram_count ) {
#                
#                print "****", encode_utf8($gram) , " ===> ", $batch_ngram_count->{$gram} ,"\n";
#                
#            }


        }
#        print "\n----------\n";
        
    }
    print "\n++++++++++++++ \n";
    
#    foreach my $gram ( 
#        sort { $batch_ngram_count->{$b} <=> $batch_ngram_count->{$a} }
#        keys %$batch_ngram_count ) {
#        
#        print "++++", encode_utf8($gram) , " ===> ", $batch_ngram_count->{$gram} ,"\n";
#        
#    }
    
#    exit;
}

#print "ngram_combo == ", Dumper($ngram_combo) , "\n";
print "Count item = $batch_count_doc \n";

foreach my $gram ( 
    sort { $batch_ngram_count->{$b} <=> $batch_ngram_count->{$a} }
    keys %$batch_ngram_count ) {
    
    print "++++", encode_utf8($gram) , " ===> ", $batch_ngram_count->{$gram} ,"\n" if ($batch_ngram_count->{$gram} > 1);
    
}

print "\n------------- \n";

foreach my $gram ( 
    sort { $batch_gram_count->{$b} <=> $batch_gram_count->{$a} }
    keys %$batch_gram_count ) {
    
    print "----", encode_utf8($gram) , " ===> ", $batch_gram_count->{$gram} ,"\n";
    
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

sub _merge_to_hash {
    my ($hash, $item_ngram) = @_;
    
    
    return $hash;
}

##    my $ngrams = $engine_NG->return_ngrams();
###    print "ngrams == ", Dumper($ngrams), "\n";
##    
##    my $sorted_results = {};
##    
##    foreach my $gram ( 
##        sort { $ngrams->{$b} <=> $ngrams->{$a} }
##        keys %$ngrams ) {
##        
##        my @gram_size_ = split(' ', $gram);
##        my $gram_size = @gram_size_;
##        my $gram_score = sprintf("%4d", $gram_size * ($ngrams->{$gram}/100) *1000  );
##        
###        print "    ", encode_utf8($gram) , " ===> ", $ngrams->{$gram}, " count ",$gram_score ,"\n";
##        
##        $sorted_results->{$gram . "===> ". $ngrams->{$gram}} = $gram_score
##        
##        
##    }
##    
##    # show sorted
##    foreach my $sorted_result ( 
##        sort { $sorted_results->{$b} <=> $sorted_results->{$a} }
##        keys %$sorted_results ) {
##        
##        print "    ", encode_utf8($sorted_result) , " score: ", $sorted_results->{$sorted_result}, "\n";
##    }
    
    

# http://search.cpan.org/~kubina/Text-Summarize-0.50/lib/Text/Summarize.pm

# 1. get all grams that in clude chars
#      ex เป็ด => [ เป ป็ ๊ด เป็ ป๊ด เป็ด ]
# 2. try to prove that [ เป ป็ ๊ด เป็ ป๊ด ] are not exist by comparing probability of words occuring
#      In 1 document => prob of เป็ด with [เป ป็ ๊ด เป็ ป๊ด] vs เป็ด without [เป ป็ ๊ด เป็ ป๊ด]
# ???      เป็ด with [เป ป็ ๊ด เป็ ป๊ด] * เป็ด without [เป ป็ ๊ด เป็ ป๊ด] / all doc with เป็ด 

# http://easycalculation.com/statistics/learn-multiple-event-probability.php ***
# http://easycalculation.com/statistics/probability.php




##################################

#(02:35:15 PM) a: dong
#(02:35:20 PM) a: https://gist.github.com/5fb48b395a09f3c0f8c9
#(02:36:02 PM) dong: แจ่ม :D
#(02:37:01 PM) a: เราเอา data ลงไม่ได้ เลย เขียน code เชื่อมกับ database ดู ไม่ยังไม่ได้ test ส่วนที่ติดต่อ DB นะ
#(02:38:38 PM) a: ตัดคำได้แล้ว จะให้  Solr หาอะไรบ้าง
#(02:39:54 PM) dong: น่าจะมี title, description , category นะ
#(02:40:20 PM) a: ok
#(02:40:21 PM) a: http://www.wired.com/gadgetlab/2012/04/can-an-algorithm-write-a-better-news-story-than-a-human-reporter/
#(02:45:30 PM) a: dong จะให้เขียน doc ที่ไหน wiki ปะ
#(02:46:15 PM) dong: เอาเลย a
#(02:46:22 PM) dong: article แจ่มมาก
#(02:46:36 PM) a: ออ
#(02:50:32 PM) a: dong: เราเข้าไปเขียน doc เกี่ยวกับ Solr config ใน comment ใน bugs.startsiden.no/browse/HACK-46 ละกัน
#(03:07:34 PM) dong: ผมทำ ngram ได้ละ มาดูๆ
#(03:36:57 PM) a: กำลังอ่าน Automatic summarization
#(03:45:42 PM) a: dong: เคยลองใช้ TextRank ไหม
#(03:45:56 PM) dong: ไม่เคยอะ มันคือ ?
#(03:46:43 PM) a: http://joshbohde.com/blog/document-summarization
#(03:54:52 PM) a: http://search.cpan.org/~kubina/Text-Summarize-0.50/lib/Text/Summarize.pm
#(03:56:18 PM) dong: แจ่มเลย เด๋วต้องลอง
#(03:57:15 PM) a: ไม่รู้มันจะใช้กับภาษาไทยดีไหม?
#(03:57:36 PM) dong: ถ้าตัดคำให้ น่าจะได้นะ
#(05:14:31 PM) a: metacpan.org/module/Treex


