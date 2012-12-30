use strict;
use warnings;
use Data::Dumper;

use Test::More tests => 5;
BEGIN { use_ok('novus::thai::collector') };
BEGIN { use_ok('novus::thai::schema') };
BEGIN { use_ok('novus::thai::utils') };
BEGIN { use_ok('novus::thai::collector::ngram') };

my $engine_NG = novus::thai::collector::ngram->new(windowsize => 2);

$engine_NG->feed_tokens("a");
$engine_NG->feed_tokens("b");
$engine_NG->feed_tokens("c");
$engine_NG->feed_tokens("a");
$engine_NG->feed_tokens("c");
$engine_NG->feed_tokens("b");
$engine_NG->feed_tokens("a");
$engine_NG->feed_tokens("b");
$engine_NG->feed_tokens("c");
$engine_NG->feed_tokens("d");

my $ngrams = $engine_NG->return_ngrams();

my $output_2grams = {
    'a b' => 2,
    'b c' => 2,
    'a' => 3,
    'b' => 3,
    'c' => 3,
    'd' => 1
};
is_deeply($ngrams,$output_2grams, 'Generate 2-grams result correctly' );

