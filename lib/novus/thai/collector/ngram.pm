package novus::thai::collector::ngram;

use strict;
use warnings;
use Encode;
use Moose;

has 'windowsize'   => (is => 'rw', isa => 'Int', default => 3);
has 'min_count'    => (is => 'rw', isa => 'Int', default => 2);
has 'normalize'    => (is => 'rw', isa => 'Int', default => 0);

sub BUILD {
    my $self = shift;
    
    $self->{'table'} = [ ];
    $self->{'total'} = [ ];
    $self->{'total_distinct_count'} = 0;
    $self->{'lastngram'} = [ ];
    $self->{'next_token_id'} = 0;
    $self->{'token_dict'} = { };
    $self->{'token_S'} = [ ];
    $self->{'token'} = [ ];
    
}

sub feed_tokens {
    my $self = shift;
    # count all n-grams sizes starting from max to 1
    foreach my $t1 (@_) {
        my $t = $t1;
        if (defined($self->{token_dict}->{$t})) {
            $t = $self->{token_dict}->{$t};
        } else {
            my $id = $self->{next_token_id}++;
            
            $self->{token_S}->[$id] = $t;
            $self->{token}->[$id]   = $t;
            $t = $self->{token_dict}->{$t} = $id;
        }
        
        for (my $n=$self->{windowsize}; $n > 0; $n--) {
            if ($n > 1) {
                next unless (defined($self->{lastngram}[$n-1]) and $self->{lastngram}[$n-1] ne '');
                $self->{lastngram}[$n] = $self->{lastngram}[$n-1] .
                ' ' . $t;
            } else { 
                $self->{lastngram}[$n] = $t 
            }

            if ( ($self->{table}[$n]{$self->{lastngram}[$n]} += 1)==1)
                { $self->{'total_distinct_count'} += 1 }

            $self->{'total'}[$n] += 1;
            if (!defined($self->{'firstngram'}[$n]) or $self->{'firstngram'}[$n] eq '')
                { $self->{'firstngram'}[$n] = $self->{lastngram}[$n] }
        }
    }
}

sub return_ngrams {
    my $self = shift;
    my (%params) = @_;
    
    #default value of 3 for ngram size
    my $n = exists($params{'n'})? $params{'n'} : $self->{windowsize};
    delete $params{'n'};
    
    my $opt_normalize = $self->{'normalize'};
    
    my $ret = {};
    
    for (my $n_count = $n; $n_count >= 1; $n_count--) {
        my $total = $self->{total}[$n_count]; # total for each gram
        my $ids_count = $self->{table}[$n_count];
        
        foreach my $ids (sort keys %$ids_count) {
            my $count = $ids_count->{$ids};
            $count = ($opt_normalize ? ($count / $total ) : $count); # normalize
            
            if ($n_count > 1) {
                # return only frequency >= min_count
                if ($ids_count->{$ids} >= $self->{min_count}) {
                    $ret->{$self->_id_to_token($ids)} = $count;
                }
                
            } else {
                $ret->{$self->_id_to_token($ids)} = $count;
            }
        }
    }
    return $ret;
}

sub _id_to_token {
    my $self = shift;
    my @r = ();
    while (@_) {
        push @r,
        map { $self->{token_S}->[$_] } split(/ /, shift @_);
    }
    return join(' ', @r);
}

1;

__END__
