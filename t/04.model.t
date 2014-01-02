#!/usr/bin/perl -w
use strict;
use warnings;

use Data::Dumper;

use Test::More tests => 5;
BEGIN { use_ok('Lingua::Model::Ngram::Count') };
BEGIN { use_ok('novus::thai::collector::ngram::model') };

subtest 'Create Count N-grams hash' => sub {
    my $model_engine = novus::thai::collector::ngram::model->new(
                                timeslot_start  => "2013-01-01 06:00:00",
                                timeslot_end    => "2013-01-01 07:00:00",
                                ngram_filepath  => './test_count.hash',
    );
    
    my $count_hash = $model_engine->ngram_count(2);
    isa_ok($count_hash, 'HASH', "Return Hash if return mode = 2");
    
    my $count_file = $model_engine->ngram_count();
    
    ok((-e $count_file), "Save Ngram count @ $count_file");
    
    # destroy old object
    $model_engine = undef;
    $model_engine = novus::thai::collector::ngram::model->new(
                                ngram_filepath  => './test_count.hash',
    );
    
    # read from storage, use path from 'filepath'
    my $ngram_count = $model_engine->restore_ngram_count();
    
    # Term frequency
    ok($ngram_count->{'CORPUS'}->{'TF'} > 0, "TF CORPUS size > 0 => ". $ngram_count->{'CORPUS'}->{'TF'});
    ok($ngram_count->{'*-*'}->{'TF'} > 0, "TF Start sequence '*-*' > 0 => ". $ngram_count->{'*-*'}->{'TF'});
    ok($ngram_count->{'*'}->{'TF'} > 0, "TF Start sequence '*' > 0 => ". $ngram_count->{'*'}->{'TF'});
    
    # Document frequency
    ok($ngram_count->{'CORPUS'}->{'DF'} > 0, "DF CORPUS size > 0 => ". $ngram_count->{'CORPUS'}->{'DF'});
    ok($ngram_count->{'*-*'}->{'DF'} > 0, "DF Start sequence '*-*' > 0 => ". $ngram_count->{'*-*'}->{'DF'});
    ok($ngram_count->{'*'}->{'DF'} > 0, "DF Start sequence '*' > 0 => ". $ngram_count->{'*'}->{'DF'});
    
#    print "ngram_count == ", Dumper($ngram_count);
    
    # remove test file
    if(-e $count_file) { unlink($count_file); }
};

subtest 'Create Count N-grams hash by category' => sub {
    my $model_engine = novus::thai::collector::ngram::model->new(
                                ngram_category  => 7, # ข่าวด่วน
                                timeslot_start  => "2013-01-01 06:00:00",
                                timeslot_end    => "2013-01-01 07:00:00",
    );
    
    my $count_hash = $model_engine->ngram_count(2);
    isa_ok($count_hash, 'HASH', "Return Hash of ngram count by category");
    
};

subtest 'Map reduce N-grams' => sub {
    my $key_phrases = {
            '6069-4995-10849' => 
                {'TF' => 2, 'DF' => 1, 'PROB' => 0.000000000480297, 'key_length' => 3},
            '6069-4994-1087' => 
                {'TF' => 2, 'DF' => 1, 'PROB' => 0.000000000000264, 'key_length' => 3},
            '18758-18550-18837-11243' => 
                {'TF' => 1, 'DF' => 1, 'PROB' => 0.000035443292623, 'key_length' => 4},
            '18550-18837-11243' => 
                {'TF' => 2, 'DF' => 1, 'PROB' => 0.000013350432564, 'key_length' => 3},
            '18758-18550' => 
                {'TF' => 3, 'DF' => 1, 'PROB' => 0.000125222358720, 'key_length' => 2},
            '18837-11243' => 
                {'TF' => 4, 'DF' => 1, 'PROB' => 0.000048845465649, 'key_length' => 2},
    };
    
    my $model_engine = novus::thai::collector::ngram::model->new(
                                ngram_filepath  => './t/data/test_count.hash',
    );
    
    $key_phrases = $model_engine->_ngram_map_reduce($key_phrases);
    my $expected_key_phrases = {
            '6069-4995-10849' => 
                {'TF' => 2, 'DF' => 1, 'PROB' => 0.000000000480297, 'key_length' => 3},
            '6069-4994-1087' => 
                {'TF' => 2, 'DF' => 1, 'PROB' => 0.000000000000264, 'key_length' => 3},
            '18758-18550-18837-11243' => 
                {'TF' => 3, 'DF' => 1, 'PROB' => 0.000035443292623, 'key_length' => 4},
            '18550-18837-11243' => 
                {'TF' => 0, 'DF' => 1, 'PROB' => 0.000013350432564, 'key_length' => 3},
            '18758-18550' => 
                {'TF' => 3, 'DF' => 1, 'PROB' => 0.000125222358720, 'key_length' => 2},
            '18837-11243' => 
                {'TF' => 4, 'DF' => 1, 'PROB' => 0.000048845465649, 'key_length' => 2},
    };
    
    # comper probability of sentence
    # move TF of 18550-18837-11243 to 18758-18550-18837-11243
    is_deeply($key_phrases, $expected_key_phrases, "Low probability token is reduce");
    
};

##นั่ง-ตาก-ลม [6069-4995-10849] probability = 0.000000000480297
##นั่ง-ตา-กลม [6069-4994-1087] probability = 0.000000000000264
##แบ-บน-อก [17967-6331-14183] probability = 0.000000000029293
##แบบ-นอก [17976-6031] probability = 0.000000105845851
##โม-โต-โร-ล่า [18758-18550-18837-11243] probability = 0.000035443292623
##โต-โร-ล่า [18550-18837-11243] probability = 0.000013350432564
##โม-โต [18758-18550] probability = 0.000125222358720
##โร-ล่า [18837-11243] probability = 0.000048845465649
##สุ-เทพ-็-อบ [13356-16425-67-14401] probability = 0.000000106677377
