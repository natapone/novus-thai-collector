use strict;
use warnings;
use Data::Dumper;

use Test::More tests => 13;
BEGIN { use_ok('novus::thai::collector') };
BEGIN { use_ok('novus::thai::schema') };
BEGIN { use_ok('novus::thai::utils') };
BEGIN { use_ok('novus::thai::collector::tokenizer') };

use Encode;

my $config = novus::thai::utils->get_config();
my $schema = novus::thai::schema->connect(
                                $config->{connect_info}[0], 
                                $config->{connect_info}[1], 
                                $config->{connect_info}[2], 
                                $config->{connect_info}[3], 
                                );
                                
my $context = "ส.ส.กทม.“เพื่อไทย”หยุดเสนอชื่อ 'สุดารัตน์'ชิงผู้ว่าฯกทม.";
# "ส.ส.กทม.เพื่อไทยหยุดเสนอชื่อ 'สุดารัตน์'ชิงผู้ว่าฯกทม."
#'พี่เป้นั่งตากลมตากลม'
#'รมว.อุตสาหกรรม พอใจโรดโชว์อินเดีย-บังคลาเทศ ดึงยักษ์ใหญ่ลงทุนในไทย'
# ทำไม .. ?????(3)

# เครืองหยายวรรคตอน
# http://www.tlcthai.com/education/knowledge-online/content-edu/thai-content-edu/16641.html

my $tokenizer = novus::thai::collector::tokenizer->new('debug' => 2 );
my $tokens = $tokenizer->tokenize($context);
###print Dumper($tokens);

print join("-", (@{$tokens->{'token'}->{'keyword'}})) , "\n";

is(defined($tokens->{'vsm'}->{'id'}), 1, "Return VSM of id correctly" );
is(defined($tokens->{'vsm'}->{'keyword'}), 1, "Return VSM of keywords correctly" );
is(defined($tokens->{'token'}->{'id'}), 1, "Return tokens of id correctly" );
is(defined($tokens->{'token'}->{'keyword'}), 1, "Return tokens of keywords correctly" );

my $token_ids = $tokenizer->tokenize_id($context);
my $expect_token_ids = [
          [
            20631,
            20425
          ],
          [
            16865,
            19219
          ],
          [
            13835,
            17340,
            4085
          ],
          [
            13404,
            10545
          ],
          [
            4032,
            8139,
            11908,
            47,
            20425
          ]
        ];
is_deeply($token_ids, $expect_token_ids, "Return tokens with split at possible keyword");

$context = "ทำไม .. ?????(3)";
$token_ids = $tokenizer->tokenize_id($context);
#print Dumper($token_ids);
$expect_token_ids = [
          [
            5652
          ],
          [
            28898
          ]
        ];
is_deeply($token_ids, $expect_token_ids, "remove empty token");

my $id_list = '1 1 1 1 1';
my $expected_string = decode_utf8('ก ก ก ก ก');
my $token_string = $tokenizer->id_to_keyword($id_list);
is($token_string, $expected_string, "id $id_list to token is correct");

$id_list = '1-1-1-1-1';
$token_string = $tokenizer->id_to_keyword($id_list, '-');
is($token_string, $expected_string, "id $id_list to token is correct");

$context = "ม๊อบเฟสล๊อก";
my $token_ids = $tokenizer->tokenize_id($context);
#print Dumper($token_ids);

my $string_from_ids = "";
foreach (@$token_ids) {
    my $token_string = $tokenizer->id_to_keyword( join(' ', @$_));
#    print "token_string == $token_string \n";
    $token_string =~ s/\s+//g;
    $string_from_ids .= $token_string;
}
is(decode_utf8($context), $string_from_ids, "There is no missing character before vowel");



