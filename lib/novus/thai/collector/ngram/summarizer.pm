package novus::thai::collector::ngram::summarizer;

use strict;
use warnings;
use Moose;

use novus::thai::collector::ngram::model;

use Data::Dumper;

our $VERSION = '0.01';

=head1 NAME
Lingua::Model::Ngram::Text

=head1 DESCRIPTION
Summarize key phrases over period of time

=cut

has 'ngram_filepath'  => (is => 'rw', isa => 'Str', lazy => 1, builder => '_build_ngram_filepath');
has 'ngram_category'  => (is => 'rw', isa => 'Str', lazy => 1, default => 0); # all cats
has 'ngram_order'       => (is => 'rw', isa => 'Str', lazy => 1, default => 8);

has 'timeslot_start' => (is => 'rw', isa => 'Str', lazy => 1, default => "2013-12-01 00:00:00");
has 'timeslot_end'   => (is => 'rw', isa => 'Str', lazy => 1, default => "2014-01-01 00:00:00");

has 'nt_model_engine'   => (is => 'ro', isa => 'novus::thai::collector::ngram::model', 
                        lazy => 1, builder => '_build_nt_model_engine');

has 'min_count'         => (is => 'rw', isa => 'Int', default => 3);
has 'min_key_length'    => (is => 'rw', isa => 'Int', default => 2);

sub _build_nt_model_engine {
    my $self = shift;
    
    return novus::thai::collector::ngram::model->new(
                            is_summarizer   => 1,
                            timeslot_start  => $self->timeslot_start,
                            timeslot_end    => $self->timeslot_end,
                            ngram_category  => $self->ngram_category,
                            ngram_order     => $self->ngram_order,
                        );
}


sub _build_ngram_filepath {
    die "Missing path to ngram_count.hash!";
}

sub summarize {
    my $self = shift;
    
    print "Start summarizer..!\n";
    
    # 2 = return hash
    my $ngram_count = $self->nt_model_engine->ngram_count(2); 
#    print Dumper($ngram_count ); exit;
    
    my $key_phrases;
    my $total_doc = $ngram_count->{'CORPUS'}->{'DF'}; # total number for documents
    foreach my $ngram ( keys %$ngram_count ) {
        my $key_length = $self->_key_length($ngram);
        if ($ngram_count->{$ngram}->{'TF'} >= $self->min_count 
            and $key_length >= $self->min_key_length 
            and ( 
                $ngram ne '*' and $ngram ne '*-*' and 
                $ngram ne 'STOP' and $ngram ne '*-*-STOP' and $ngram ne '*-STOP'
            )
        ) {
#            print "count $ngram == ", $ngram_count->{$ngram}->{'TF'} , "/", $ngram_count->{$ngram}->{'DF'} , " l=$key_length " , "\n";
            $key_phrases->{$ngram}->{'key_length'} = $key_length;
#            $key_phrases->{$ngram}->{'TF'} = $ngram_count->{$ngram}->{'TF'};
#            $key_phrases->{$ngram}->{'DF'} = $ngram_count->{$ngram}->{'DF'};
            
            # Cal TF-IDF
            my $tf_score    = log($ngram_count->{$ngram}->{'TF'} + 1); # tf log scale
            if ($ngram_count->{$ngram}->{'DF'} != 0) {
                my $idf_score   = log($total_doc / $ngram_count->{$ngram}->{'DF'});
                $tf_score  *= $idf_score;
#                print "    TF-IDF => $tf_score \n\n";
            }
            
            $key_phrases->{$ngram}->{'TFIDF'} = $tf_score;
        }
    }
    
    # clean up memory
    $ngram_count = undef;
    
    # calculate probability
####    foreach my $ngram ( 
#####        sort { $key_phrases->{$a}->{'key_length'} <=> $key_phrases->{$b}->{'key_length'} }
####        sort { $key_phrases->{$b}->{'TFIDF'} <=> $key_phrases->{$a}->{'TFIDF'} }
####        keys %$key_phrases ) {
####        
####        print $ngram, " ";
####        print Dumper($key_phrases->{$ngram});
####        
####    }
    
#    print Dumper($key_phrases);
    return $key_phrases;
}

sub _key_length {
    my $self = shift;
    my $key = shift;
    
    my @keys = split('-', $key);
    return scalar @keys;
}

1;
