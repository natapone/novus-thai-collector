use strict;
use warnings;
use Data::Dumper;

use Test::More tests => 8;
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
                                
my $context = 'พี่เป้นั่งตากลมตากลม';
#'พี่เป้นั่งตากลมตากลม'
#'รมว.อุตสาหกรรม พอใจโรดโชว์อินเดีย-บังคลาเทศ ดึงยักษ์ใหญ่ลงทุนในไทย'

$context = decode_utf8($context); # fix encoding

my $tokenizer = novus::thai::collector::tokenizer->new('debug' => 0 );
my $tokens = $tokenizer->tokenize($context);

is(defined($tokens->{'vsm'}->{'id'}), 1, "Return VSM of id correctly" );
is(defined($tokens->{'vsm'}->{'keyword'}), 1, "Return VSM of keywords correctly" );
is(defined($tokens->{'token'}->{'id'}), 1, "Return tokens of id correctly" );
is(defined($tokens->{'token'}->{'keyword'}), 1, "Return tokens of keywords correctly" );


