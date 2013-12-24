#!/usr/bin/perl -w
use strict;
use warnings;

use Data::Dumper;
use novus::thai::collector::ngram::model;

my $model_engine = novus::thai::collector::ngram::model->new(
                            timeslot_start  => "2012-01-01 00:00:00",
                            timeslot_end    => "2014-01-01 00:00:00",
);

my $count_file = $model_engine->ngram_count();





