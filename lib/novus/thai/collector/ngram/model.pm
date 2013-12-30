package novus::thai::collector::ngram::model;

use strict;
use warnings;
use Moose;

use Storable;
use Term::ProgressBar;
use Data::CosineSimilarity;

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

has 'ngram_category'  => (is => 'rw', isa => 'Str', lazy => 1, default => 0); # all cats

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
    my $return_mode = shift || 1; # 1 = file path, 2 = return_ngram_count
    
    my $timestamp_start = novus::thai::utils->string_to_timestamp($self->timeslot_start);
    my $timestamp_end   = novus::thai::utils->string_to_timestamp($self->timeslot_end);
    
    # get data between period of time
    print "Time start = ",$self->timeslot_start," ==> $timestamp_start \n";
    print "Time end   = ",$self->timeslot_end," ==> $timestamp_end \n";
    
    my $categories = $self->schema->resultset('Category');
    
    my $feeds;
    if ($self->ngram_category > 0) {
        my $category = $categories->find($self->ngram_category);
        
        # list feeds from category
        $feeds = $category->feeds;
        
    } else {
        $feeds = $self->schema->resultset('Feed');
        
    }
    
    # skip feed from Pantip
    $feeds = $feeds->search(
        {
            id => {
                    '-or' => {
                        '<' => 99,
                        '>' => 122 
                    }
                },
        }, { ORDER_BY => 'id' }
    );
    
    my @feed_list = $feeds->get_column('id')->all;
    print "feed_list == ", join('-', @feed_list), "\n";
    
    my $items = $self->schema->resultset('Item')->search(
                                { 
                                    timestamp => {
                                        -between => [
                                            $timestamp_start,
                                            $timestamp_end,
                                        ],
                                    },
                                    feedid => {
                                        'in' => \@feed_list
                                    },
                                    
                                    
                                } , {
                                    rows => 100_000,
                                    ORDER_BY => "RANDOM()",
                                }
                            );
    
    die "Empty record set" if ($items->count <= 0);
    
    my $progress_bar = Term::ProgressBar->new({
                            count   => $items->count, 
                            name    => 'Count ngram',
                        });
    
    # -------------
    my $i_count = 0;
    while (my $item = $items->next) {
        # item data
##        print "title = ", $item->title, "\n";
##        print "description = ", $item->description, "\n";
##        print "category = ", $item->category, "\n";
        
        my $context = $item->title;
        
        $self->_add_context_to_ngram_counter($context);
        # add description
        if ($item->description) {
            $context = $item->description;
            $self->_add_context_to_ngram_counter($context);
        }
        # add keyword from category
        if ($item->category) {
            if ($item->category =~ /\{(.+)\}/) {
#                print "match == $1 \n";
                my $categories = eval "[$1]";
                
                foreach my $category (@$categories) {
#                    print "    ---- $category \n";
                    $self->_add_context_to_ngram_counter($category);
                }
                
            } else {
#                print "not match == ", $item->category ," \n";
                $self->_add_context_to_ngram_counter($item->category);
            }
            
        }
        
        # Doc end, add DF
        $self->ngram_counter->add_df;
        
        $i_count++;
        if($i_count % 100 == 0) {
            $progress_bar->update($i_count);
        }
#        exit;
    }
    $progress_bar->update($items->count());
    # -------------
    
#    print "ngram_counter == ", Dumper($self->ngram_counter->return_ngram_count), "\n";
    print "Count Item == ", $items->count(), "\n";
    
    if ($return_mode == 1) {
        # save hash to file
        print "Save Ngram count to ", $self->ngram_filepath, "\n";
        store(
            $self->ngram_counter->return_ngram_count, $self->ngram_filepath
        ) || die "can't store to ",$self->ngram_filepath,"\n";
        
        return $self->ngram_filepath;
    } elsif ($return_mode == 2) {
        # return ngram count as hashref
        return $self->ngram_counter->return_ngram_count;
    }
}

sub _ngram_map_reduce {
    my $self = shift;
    my $ngram_count = shift;
    
    print Dumper($ngram_count);
    
    print "Start map reduce duplicate keys.....!\n";
    my $cs = Data::CosineSimilarity->new;
    
    # create VSM for similarlity check
    foreach my $ngram ( keys %$ngram_count ) {
        my $vsm = _list_to_vsm($ngram);
        $cs->add( $ngram => $vsm );
    }
    
    foreach my $ngram ( 
        sort { $self->_key_length($a) <=> $self->_key_length($b) }
        keys %$ngram_count ) {
        
        print $ngram , " l=", $self->_key_length($ngram) , "\n";
        
        my ($best_label, $r) = $cs->best_for_label($ngram);
        
        print Dumper($best_label);
        print Dumper($r);
    }
    
    
###    foreach my $ngram ( 
###        sort { $self->_key_length($a) <=> $self->_key_length($b) }
###        keys %$ngram_count ) {
###        
###        print $ngram , " l=", $self->_key_length($ngram) , "\n";
###        
#####        delete $ngram_count->{'18837-11243'}; 
#####        $ngram_count->{'18758-18550-18837-11243'}++;
###        
###        # get similar key
###        
###        # compare similarity
###        
###    }
###    
#####    my $key1 = "18837-11243";
#####    
#####    my @keys = grep m/$key1/so => keys %{$ngram_count};
#####    print Dumper(\@keys);
    
#    print Dumper($ngram_count);
}

sub _list_to_vsm {
    my $str_id = shift;
    my $vsm = {};
    
    my @ids = split('-', $str_id);
    foreach (@ids) {
        $vsm = _add_to_vsm($vsm, $_);
    }
    
    return $vsm;
}

sub _add_to_vsm {
    my ($vsm, $new_key) = @_;
    
    if ($vsm->{$new_key}) {
        $vsm->{$new_key}++;
    } else {
        $vsm->{$new_key} = 1;
    }
    
    return $vsm;
}

sub _key_length {
    my $self = shift;
    my $key = shift;
    
    my @keys = split('-', $key);
    return scalar @keys;
}

sub _add_context_to_ngram_counter {
    my $self = shift;
    my $context = shift;
    
#    print "context == $context \n";
    my $tokens = $self->tokenizer->tokenize_id($context);
#    print Dumper($tokens);
    
    foreach my $token (@$tokens) {
        
        my $id_tokens = $token;
#        print "-- id to keyword", $self->tokenizer->id_to_keyword( join(' ', @$id_tokens) ) , "\n";
        
        # 2nd order Markov use ngram from 3 - 0
        my $markov_order = 2;
        for my $ngram_size ( 0 .. $markov_order + 1) {
            my $params = {
                start_stop => 1,
                window_size => $ngram_size,
            };
            my $ngrams = $self->text_engine->ngram($id_tokens, $params);
#            print "ngrams == ", Dumper($ngrams), "\n";
            
            $self->ngram_counter->add_ngram($ngrams);
        }
    }
    
    
##    print "CORPUS == ", $self->ngram_counter->return_ngram_count->{'CORPUS'}, "\n";
}







1;
