package novus::thai::collector::ngram::model;

use strict;
use warnings;
use Moose;

use Storable;
use Term::ProgressBar;

use novus::thai::utils;
use novus::thai::schema;
use novus::thai::collector::tokenizer;

use Lingua::Model::Ngram::Text;
use Lingua::Model::Ngram::Count;

use Data::Dumper;

our $VERSION = '0.01';

=head1 NAME
Lingua::Model::Ngram::Text

=head1 DESCRIPTION
Create Thai language from N-gram language model 2nd order Markov

=cut
has 'ngram_filename'  => (is => 'rw', isa => 'Str', lazy => 1, default => "ngram_count.hash");
has 'ngram_filepath'  => (is => 'rw', isa => 'Str', lazy => 1, builder => '_build_ngram_filepath');

has 'timeslot_start' => (is => 'rw', isa => 'Str', lazy => 1, default => "2012-01-01 00:00:00");
has 'timeslot_end'   => (is => 'rw', isa => 'Str', lazy => 1, default => "2013-01-01 00:00:00");

has 'schema'    => (is => 'ro', lazy => 1, builder => '_build_schema');
has 'config'    => (is => 'ro', isa => 'HashRef', lazy => 1, builder => '_build_config');

has 'tokenizer' => (is => 'ro', isa => 'novus::thai::collector::tokenizer', 
                    lazy => 1, builder => '_build_tokenizer');

has 'text_engine' => (is => 'ro', isa => 'Lingua::Model::Ngram::Text', 
                    lazy => 1, builder => '_build_text_engine');

has 'ngram_counter' => (is => 'ro', isa => 'Lingua::Model::Ngram::Count', 
                    lazy => 1, builder => '_build_ngram_counter');

sub _build_config {
    return novus::thai::utils->get_config();
}

sub _build_schema {
    my $self = shift;
    
    return novus::thai::schema->connect(
                                $self->config->{connect_info}[0], 
                                $self->config->{connect_info}[1], 
                                $self->config->{connect_info}[2], 
                                $self->config->{connect_info}[3], 
                            );
}

sub _build_tokenizer {
    my $self = shift;
    
    return novus::thai::collector::tokenizer->new('debug' => 0 );
}

sub _build_text_engine {
    return Lingua::Model::Ngram::Text->new();
}

sub _build_ngram_counter {
    return Lingua::Model::Ngram::Count->new();
}

sub _build_ngram_filepath {
    my $self = shift;
    
    return "./etc/".$self->ngram_filename;
}

sub restore_ngram_count {
    my $self = shift;
    
    return retrieve($self->ngram_filepath) || die "Missing Ngram file @ ", $self->ngram_filepath;
}

sub ngram_count {
    my $self = shift;
    
    my $timestamp_start = novus::thai::utils->string_to_timestamp($self->timeslot_start);
    my $timestamp_end   = novus::thai::utils->string_to_timestamp($self->timeslot_end);
    
    # get data between period of time
    print "Time start = ",$self->timeslot_start," ==> $timestamp_start \n";
    print "Time end   = ",$self->timeslot_end," ==> $timestamp_end \n";
    
    my $items = $self->schema->resultset('Item')->search(
                                { 
                                    timestamp => {
                                        -between => [
                                            $timestamp_start,
                                            $timestamp_end,
                                        ],
                                    }
                                } , {
#                                    rows => 34
                                }
                            );
    
    die "Empty record set" if ($items->count <= 0);
    
    my $progress_bar = Term::ProgressBar->new({
                            count   => $items->count, 
                            name    => 'Count ngram',
                        });
    
    my $i_count = 0;
    
    while (my $item = $items->next) {
        my $context = $item->title;
        
        $self->_add_context_to_ngram_counter($context);
        
        if ($item->description) {
            $context = $item->description;
            $self->_add_context_to_ngram_counter($context);
        }
        
        $i_count++;
        
        if($i_count % 100 == 0) {
            $progress_bar->update($i_count);
        }
#        exit;
    }
    $progress_bar->update($items->count());
    
#    print "ngram_counter == ", Dumper($self->ngram_counter->return_ngram_count), "\n";
    print "Count Item == ", $items->count(), "\n";
    
    # save hash to file
    print "Save Ngram count to ", $self->ngram_filepath, "\n";
    store(
        $self->ngram_counter->return_ngram_count, $self->ngram_filepath
    ) || die "can't store to ",$self->ngram_filepath,"\n";
    
    return $self->ngram_filepath;
}

sub _add_context_to_ngram_counter {
    my $self = shift;
    my $context = shift;
    
    my $tokens = $self->tokenizer->tokenize($context);
    my $id_tokens = $tokens->{'token'}->{'id'};
#    print "-- id to keyword", $self->tokenizer->id_to_keyword( join(' ', @$id_tokens) );
    
    # 2nd order Markov use ngram from 3 - 0
    my $markov_order = 2;
    for my $ngram_size ( 0 .. $markov_order + 1) {
        my $params = {
            start_stop => 1,
            window_size => $ngram_size,
        };
        my $ngrams = $self->text_engine->ngram($id_tokens, $params);
#        print "ngrams == ", Dumper($ngrams), "\n";
        
        $self->ngram_counter->add_ngram($ngrams);
    }
##    print "CORPUS == ", $self->ngram_counter->return_ngram_count->{'CORPUS'}, "\n";
}







1;
