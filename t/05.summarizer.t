#!/usr/bin/perl -w
use strict;
use warnings;

use Data::Dumper;

use Test::More tests => 2;
BEGIN { use_ok('novus::thai::collector::ngram::summarizer') };
BEGIN { use_ok('novus::thai::collector::tokenizer') };

my $tokenizer = novus::thai::collector::tokenizer->new();

subtest 'Extract key phrase' => sub {
    
    my $summarizer = novus::thai::collector::ngram::summarizer->new(
                                    ngram_category  => 4,
                                    ngram_order     => 5,
                                    timeslot_start  => "2013-12-9 00:00:00",
                                    timeslot_end    => "2013-12-10 00:00:00",
#                                    ngram_filepath  => './t/data/ngram_count.hash',
                                    ngram_filepath  => './etc/ngram_count_130k',
    );
    
    my $keywords = $summarizer->summarize();
    
#    print Dumper($keywords);
    
    foreach my $ngram ( 
#        sort { $keywords->{$a}->{'key_length'} <=> $keywords->{$b}->{'key_length'} }
        sort { $keywords->{$b}->{'TFIDF'} <=> $keywords->{$a}->{'TFIDF'} }
        keys %$keywords ) {
        
        print $ngram , " => ", $tokenizer->id_to_keyword($ngram, '-') , " ";
        print Dumper($keywords->{$ngram});
        
        
        
    }
    
    
};

