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
use Storable;
use Data::CosineSimilarity;

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
                                                windowsize => 7,
                                                min_windowsize => 2,
                                                min_count  => 3,
                                                );
my $cs = Data::CosineSimilarity->new;

my $idf_ref = retrieve("./etc/novus_thai_idf.dict");
my  $idf  = $$idf_ref ;  # dereferencing
$idf_ref = undef; # clean up unused large variable

#print "idf = ", Dumper($idf);
#exit;

# timeslot ==> %Y-%m-%d %H:%M:%S
my $timeslot_start = "2012-12-24 00:00:00";
my $timeslot_end   = "2012-12-25 00:00:00";

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
        
        my $token_keywords = $tokens->{'token'}->{'id'};

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
my $sorted_results = {};
my $mean_gram_score = 0;
my $g_count = 0;
my $max_f = 0; # normalize TF
foreach my $gram ( 
    sort { $ngrams->{$b} <=> $ngrams->{$a} }
    keys %$ngrams ) {
    
    # similarlity check
    my $vsm = _list_to_vsm($gram);
    $cs->add( $gram => $vsm );
    
#    my @gram_size_ = split(' ', $gram);
#    my $gram_size = @gram_size_;
#        my $gram_score = sprintf("%4d", $gram_size * ($ngrams->{$gram}/100) *1000  );

    $max_f = $ngrams->{$gram} if ($ngrams->{$gram} > $max_f);
#    my $gram_score = 1 + log($ngrams->{$gram}); # tf log scale
    my $gram_score = $ngrams->{$gram} / $max_f; # tf
    if ($idf->{$gram}) {
        $gram_score = $ngrams->{$gram} * $idf->{$gram} ;
    }
    
    
#        print "    ", encode_utf8($gram) , " ===> ", $ngrams->{$gram}, " count ",$gram_score ,"\n";
    my $ngram_keywords = $tokenizer->id_to_keyword($gram);
#    $sorted_results->{$gram ." (".$ngram_keywords.") ===> ". $ngrams->{$gram} } = $gram_score;
    $sorted_results->{$gram} = $gram_score;
    
#    print "vsm = ", Dumper($vsm), "\n";
    
    $mean_gram_score += $gram_score;
    $g_count++;
}
$mean_gram_score = $mean_gram_score / $g_count;
print "Mean score = $mean_gram_score \n";

my $r_count = keys %$sorted_results;
print "Size = ", $r_count, "\n";

# show sorted
foreach my $sorted_result ( 
    sort { $sorted_results->{$b} <=> $sorted_results->{$a} }
    keys %$sorted_results ) {
    
    # similarlity score shift
    # move score IF (in case org score is higher that best label's score')
#        1. cosine similarlity > 0.75
#        2. conditional probability P(best keyword) / P(org keyword)  > 0.5
#        3  conditional probability is less than 1 -> wrong calculation
    # resort score
    
#    my $ngram_keywords = $tokenizer->id_to_keyword($sorted_result);
#    print "    $sorted_result (", encode_utf8($ngram_keywords) , ") score = ", $sorted_results->{$sorted_result}, "\n";
    my ($best_label, $r) = $cs->best_for_label($sorted_result);
#    print "            best = ", encode_utf8($tokenizer->id_to_keyword($best_label)),
#    "  current best score=", $sorted_results->{$best_label},
#    "  c=", $r->cosine ,
#    "  p=", $ngrams->{$best_label}, "/", $ngrams->{$sorted_result},
#    "=", $ngrams->{$best_label} / $ngrams->{$sorted_result},
#    "  idf=", $idf->{$best_label}, "/", $idf->{$sorted_result},
#    "=", $idf->{$best_label} / $idf->{$sorted_result},
#    "\n";
    
    
    if ( defined($sorted_results->{$sorted_result}) and defined($sorted_results->{$best_label})  ) {
        # Compare score
        if ($sorted_results->{$sorted_result} > $sorted_results->{$best_label} ) {
            # Check cosine similarlity
            if ($r->cosine > 0.75) {
                # Cal conditional probability
                my $con_prob = $ngrams->{$best_label} / $ngrams->{$sorted_result};
                if ($con_prob >=0.5 and $con_prob <= 1) {
                    # move score to best label
                    
#                    print Dumper($r); exit;
                    
                    foreach ($r->labels) {
                        print "    ---- $_ (", encode_utf8($tokenizer->id_to_keyword($_)), ")  ==> ", $sorted_results->{$_} ," \n";
                    }
                    
                    
                    $sorted_results->{$best_label} = $sorted_results->{$sorted_result};
                    print "1*** ", encode_utf8($tokenizer->id_to_keyword($best_label)) , " == ", $sorted_results->{$best_label}, "\n";
                    delete $sorted_results->{$sorted_result};
                }
            }
        }
    }
    
}

$r_count = keys %$sorted_results;
print "Size = ", $r_count, "\n";


##################
#$cs = Data::CosineSimilarity->new;
#foreach my $sorted_result ( 
#    keys %$sorted_results ) {
#    
#    # similarlity check
#    my $vsm = _list_to_vsm($sorted_result);
#    $cs->add( $sorted_result => $vsm );
#    
#}

#foreach my $sorted_result ( 
#    sort { $sorted_results->{$b} <=> $sorted_results->{$a} }
#    keys %$sorted_results ) {
#    
#    # similarlity score shift
#    # move score IF (in case org score is higher that best label's score')
##        1. cosine similarlity > 0.75
##        2. conditional probability P(best keyword) / P(org keyword)  > 0.5
##        3  conditional probability is less than 1 -> wrong calculation
#    # resort score
#    
##    my $ngram_keywords = $tokenizer->id_to_keyword($sorted_result);
##    print "    $sorted_result (", encode_utf8($ngram_keywords) , ") score = ", $sorted_results->{$sorted_result}, "\n";
#    my ($best_label, $r) = $cs->best_for_label($sorted_result);
##    print "            best = ", encode_utf8($tokenizer->id_to_keyword($best_label)),
##    "  current best score=", $sorted_results->{$best_label},
##    "  c=", $r->cosine ,
##    "  p=", $ngrams->{$best_label}, "/", $ngrams->{$sorted_result},
##    "=", $ngrams->{$best_label} / $ngrams->{$sorted_result},
##    "  idf=", $idf->{$best_label}, "/", $idf->{$sorted_result},
##    "=", $idf->{$best_label} / $idf->{$sorted_result},
##    "\n";
#    
#    if ( defined($sorted_results->{$sorted_result}) and defined($sorted_results->{$best_label})  ) {
#    # Compare score
#    if ($sorted_results->{$sorted_result} > $sorted_results->{$best_label} ) {
#        # Check cosine similarlity
#        if ($r->cosine > 0.75) {
#            # Cal conditional probability
#            my $con_prob = $ngrams->{$best_label} / $ngrams->{$sorted_result};
#            if ($con_prob >=0.5 and $con_prob <= 1) {
#                # move score to best label
#                    $sorted_results->{$best_label} = $sorted_results->{$sorted_result};
#                    print "2*** ", encode_utf8($tokenizer->id_to_keyword($best_label)) , " == ", $sorted_results->{$best_label}, "\n";
#                    delete $sorted_results->{$sorted_result};
#            }
#        }
#    }
#    }
#    
#}
#$r_count = keys %$sorted_results;
#print "Size = ", $r_count, "\n";
#################


# after remove dup
# show sorted
foreach my $sorted_result ( 
    sort { $sorted_results->{$b} <=> $sorted_results->{$a} }
    keys %$sorted_results ) {
    
    my $ngram_keywords = $tokenizer->id_to_keyword($sorted_result);
    print "    $sorted_result (", encode_utf8($ngram_keywords) , ") score = ", $sorted_results->{$sorted_result}, "\n";
}

sub _list_to_vsm {
    my $str_id = shift;
    my $vsm = {};
    
    my @ids = split(' ', $str_id);
    foreach (@ids) {
        $vsm = _add_to_vsm($vsm, $_);
    }
    
    return $vsm;
}

sub _add_to_vsm {
    my ($vsm, $new_key) = @_;
    
    if ($vsm->{$new_key}) {
        $vsm->{$new_key}++;
    } else {
        $vsm->{$new_key} = 1;
    }
    
    return $vsm;
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


