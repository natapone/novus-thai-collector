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
my $engine_NG = novus::thai::collector::ngram->new(
                                                windowsize => 10,
                                                min_windowsize => 2,
                                                min_count  => 3,
                                                );

# timeslot ==> %Y-%m-%d %H:%M:%S
my $timeslot_start = "2012-12-24 00:00:00";
my $timeslot_end   = "2012-12-26 00:00:00";

my $timestamp_start = novus::thai::utils->string_to_timestamp($timeslot_start);
my $timestamp_end   = novus::thai::utils->string_to_timestamp($timeslot_end);

print "Time start = $timeslot_start ==> $timestamp_start \n";
print "Time end   = $timeslot_end ==> $timestamp_end \n";

# get Keyphrase of category IT
my $category = $schema->resultset('Category')->find(2);
my $feeds    = $category->feeds();
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
        
        my $context = $item->title . " " . $item->description;
        
        my $tokens = $tokenizer->tokenize($context);
        
        my $token_keywords = $tokens->{'token'}->{'keyword'};

        foreach (@$token_keywords) {
#            print "-", encode_utf8($_);
            $engine_NG->feed_tokens($_);
        }
        
#        print "\n----------\n";
#        exit;
    }
    print "\n++++++++++++++ \n";
    
}
    my $ngrams = $engine_NG->return_ngrams();
#    print "ngrams == ", Dumper($ngrams), "\n";
    
    my $sorted_results = {};
    
    foreach my $gram ( 
        sort { $ngrams->{$b} <=> $ngrams->{$a} }
        keys %$ngrams ) {
        
        my @gram_size_ = split(' ', $gram);
        my $gram_size = @gram_size_;
        my $gram_score = sprintf("%4d", $gram_size * ($ngrams->{$gram}/100) *1000  );
        
#        print "    ", encode_utf8($gram) , " ===> ", $ngrams->{$gram}, " count ",$gram_score ,"\n";
        
        $sorted_results->{$gram . "===> ". $ngrams->{$gram}} = $gram_score
        
        
    }
    
    # show sorted
    foreach my $sorted_result ( 
        sort { $sorted_results->{$b} <=> $sorted_results->{$a} }
        keys %$sorted_results ) {
        
        print "    ", encode_utf8($sorted_result) , " score: ", $sorted_results->{$sorted_result}, "\n";
    }
    
    

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


