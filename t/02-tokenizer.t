use strict;
use warnings;
use Data::Dumper;

use Test::More tests => 10;
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




