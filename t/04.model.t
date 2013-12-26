#!/usr/bin/perl -w
use strict;
use warnings;

use Data::Dumper;

use Test::More tests => 3;
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
    
    ok($ngram_count->{'CORPUS'} > 0, "CORPUS size > 0 => ". $ngram_count->{'CORPUS'});
    ok($ngram_count->{'*-*'} > 0, "Start sequence '*-*' > 0 => ". $ngram_count->{'*-*'});
    ok($ngram_count->{'*'} > 0, "Start sequence '*' > 0 => ". $ngram_count->{'*'});
    
#    print "ngram_count == ", Dumper($ngram_count);
    
    # remove test file
    if(-e $count_file) { unlink($count_file); }
};


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
