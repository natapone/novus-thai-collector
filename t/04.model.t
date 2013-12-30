#!/usr/bin/perl -w
use strict;
use warnings;

use Data::Dumper;

use Test::More tests => 4;
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
    
}

##subtest 'Map reduce N-grams' => sub {
##    my $ngram_count = {
##            '6069-4995-10849' => 1,
##            '6069-4994-1087' => 1,
##            '18758-18550-18837-11243' => 1,
##            '18550-18837-11243' => 2,
##            '18758-18550' => 3,
##            '18837-11243' => 4,
##    };
##    
##    my $model_engine = novus::thai::collector::ngram::model->new(
##                                ngram_filepath  => './test_count.hash',
##    );
##    
##    $model_engine->_ngram_map_reduce($ngram_count);
##    
##}
