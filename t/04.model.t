#!/usr/bin/perl -w
use strict;
use warnings;

use Test::More tests => 2;
BEGIN { use_ok('Lingua::Model::Ngram::Count') };
BEGIN { use_ok('novus::thai::collector::ngram::model') };

subtest 'Create Count N-grams hash' => sub {
    my $model_engine = novus::thai::collector::ngram::model->new(
                                timeslot_start  => "2013-01-01 06:00:00",
                                timeslot_end    => "2013-01-01 07:00:00",
                                filepath        => './test_count.hash',
    );
    
    my $count_file = $model_engine->ngram_count();
    
    ok((-e $count_file), "Save Ngram count @ $count_file");
    
    # read from storage, use path from 'filepath'
##    my $ngram_count = $model_engine->restore_ngram_count();
    
    
};


