#!/usr/local/bin/perl -w

use strict;
use Data::Dumper;
use Encode;
use Try::Tiny;

use Lingua::Model::Ngram;
use novus::thai::collector::tokenizer;
use Storable;

my $context1 = "นั่งตาก ลม";
my $context2 = "นั่งตา กลม";

my $context3 = "แบ บน อก";
my $context4 = "แบบ นอก";

my $context11 = "โมโตโรล่า";
my $context12 = "โตโรล่า";
my $context13 = "โมโต";
my $context14 = "โรล่า";
# "ส.ส.กทม.เพื่อไทยหยุดเสนอชื่อ 'สุดารัตน์'ชิงผู้ว่าฯกทม."
#'พี่เป้นั่งตากลมตากลม'
#'รมว.อุตสาหกรรม พอใจโรดโชว์อินเดีย-บังคลาเทศ ดึงยักษ์ใหญ่ลงทุนในไทย'

# initial engine
our $tokenizer = novus::thai::collector::tokenizer->new('debug' => 0 );
# restore hash 
my $ngram_count = retrieve('./etc/ngram_count_500k.hash') || die "Missing Ngram file";
our $model_engine = Lingua::Model::Ngram->new(
                                        ngram_count     => $ngram_count,
                                    );

_cal_prob($context1);
_cal_prob($context2);
_cal_prob($context3);
_cal_prob($context4);

_cal_prob($context11);
_cal_prob($context12);
_cal_prob($context13);
_cal_prob($context14);

sub _cal_prob {
    my $context = shift;
    
    my $tokens = $tokenizer->tokenize($context);
    my $id_tokens = $tokens->{'token'}->{'id'};
    my $p = $model_engine->sentence_probability($id_tokens);
    
    print _fix_wild_char_print(join("-", (@{$tokens->{'token'}->{'keyword'}})))  , " probability = " , $p , "\n";
}

sub _fix_wild_char_print {
    my $str = shift;
    
    return encode_utf8($str);
}
