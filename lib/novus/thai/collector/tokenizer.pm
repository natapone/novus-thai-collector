package novus::thai::collector::tokenizer;

use strict;
use warnings;
#use Novus::Config;
#use Search::Tools::Tokenizer;
#use Lingua::Stem;
use Encode;
#use Novus::Conan::Cluster::NB::Ngram;
use Moose;
use Storable;
use novus::thai::utils;
use novus::thai::schema;
use Try::Tiny;

use Data::Dumper;


has 'dict_maxlength'    => (is => 'rw', isa => 'Int', default => 0);
has 'dict_filename'     => (is => 'rw', isa => 'Str', default => './etc/novus_thai_dict.dict');
has 'debug'             => (is => 'rw', isa => 'Int', default => 0);

my $dict_words;
my $dict_ids;
my $vowel_list;
my $entity_list;
my $config;
my $schema;

sub BUILD {
    my $self = shift;
    
    $config = novus::thai::utils->get_config();
    $schema = novus::thai::schema->connect(
                                $config->{connect_info}[0], 
                                $config->{connect_info}[1], 
                                $config->{connect_info}[2], 
                                $config->{connect_info}[3], 
                                );
    
    # load dictionary file
    unless (-e $self->{'dict_filename'}) {
        die $self->{'dict_filename'}. " not exist!";
    }
    
    # Init file for wordbreak {keyword => id}
    my $dict_ref = retrieve($self->{'dict_filename'});
    $dict_words  = $$dict_ref ;  # dereferencing
    $dict_ref = undef; # clean up unused large variable
    
    # create hash of {id => keyword}
    my %dict_ids_hash = reverse %$dict_words;
    $dict_ids = \%dict_ids_hash; 
    
    print "Finish retrieving ", $self->{'dict_filename'}, "\n" if ($self->{'debug'} > 0);
    
    # get max length
    $self->{'dict_maxlength'} = $schema->resultset('Sysconfig')->find('DICT_MAXLENGTH')->configvalue;
    
    # Init Vowel list
    my $vowel_configs = $schema->resultset('Sysconfig')->search_rs({
                                                        configname => { 'like' => 'IS_VOWEL%'},
                                                                    });
    
    while (my $vowel_config = $vowel_configs->next) {
        $vowel_list->{$vowel_config->configvalue} = 1;
    }
    
    # Init simple entity marking list
    my $entity_configs = $schema->resultset('Sysconfig')->search_rs({
                                                        configname => { 'like' => 'is_entity%'},
                                                                    });
    my @ent;
    while (my $entity_config = $entity_configs->next) {
#        $entity_list->{$entity_config->configvalue} = 1;
        push(@ent, "\\" . $entity_config->configvalue);
    }
    $entity_list = join('|', @ent);
}

sub id_to_keyword {
    my $self = shift;
    my $id_list = shift;
    
    my @ids = split(' ', $id_list);
    my @id_keywords;
    
    foreach (@ids) {
        my $id_keyword = $dict_ids->{$_};
        if (defined($id_keyword)) {
            push(@id_keywords, $id_keyword);
         } else {
            warn "missing keyword '$_'";
         }
    }
    
    return join(" ", @id_keywords);;
}

# new implement tokenize
# return only ID
# split sentence at keyword to address more probability in mode => *, W1, STOP
sub tokenize_id {
    my $self = shift;
    my $context = shift;
    
    # Try to decode, Skip if keyword is already UTF-8
    try {
        $context = decode_utf8($context, Encode::FB_CROAK);
        $entity_list = decode_utf8($entity_list, Encode::FB_CROAK);
    };
    
    # ***** check if is_entity => split sentence   \[\]\(\)\{\}\⟨\⟩\:\!\‘\’\“\”\'\"\;\?
    my @contexts = split(/$entity_list/, $context);
    my @t_ids;
    for (@contexts) {
        my $tokens = $self->tokenize($_);
        
#        print Dumper($tokens->{'token'}->{'id'});
#        exit;
        if (defined($tokens->{'token'}->{'id'}) and scalar @{$tokens->{'token'}->{'id'}} > 0) {
            push(@t_ids, $tokens->{'token'}->{'id'});
        }
        
    }
    
    return \@t_ids;
}

sub tokenize {
    my $self = shift;
    my $context = shift;
    
    # Try to decode, Skip if keyword is already UTF-8
    try {
        $context = decode_utf8($context, Encode::FB_CROAK);
    };
    
    my $breaked_string;
    my $breaked_string_id;
    
    my @result_ids;
    my @result_keywords;
    my $vsm_id;
    my $vsm_keyword;
    
    print "Start tokenize '", $context, "'\n" if ($self->{'debug'} > 0);
    
    $context = novus::thai::utils->clean_context($context);
    print "Clean context '", $context, "'\n" if ($self->{'debug'} > 2);
    
    while (length($context) > 0) {
        my $portion_1 = substr($context, 0, $self->{'dict_maxlength'});
        
        # Search longest possible from first character --- loop 2
        my $portion_2 = $portion_1;
        my $p2_hit = 0;
        
        while (length($portion_2) >= 1) {
            
            # if find --> cut and save --> back to l1
            if ($dict_words->{$portion_2}) {
                # validate Thai vowel rule, first next portion cant be in vowel list!, 1 Thai char = 3 slots
                my $chk_vowel = substr($context, length($portion_2), 1);
                
                if (!defined($vowel_list->{$chk_vowel})) { # if vowel => just skip; dict will picks next shorter word
                    my $id_tohash = $dict_words->{$portion_2};
                    
                    # Set found
                    $p2_hit =1;
                    print ("---found $id_tohash = $portion_2 \n") if ($self->{'debug'} > 2);
                    
                    # add keyword_id to gen topic
                    $vsm_id      = _add_to_vsm($vsm_id, $id_tohash);
                    $vsm_keyword = _add_to_vsm($vsm_keyword, $portion_2);
                    
                    # add string sequence to gen n-gram
                    push(@result_keywords, $portion_2);
                    
                    #n-gram by id
                    push(@result_ids, $id_tohash);
                    
                    # remove extracted word from source
                    $context = substr($context, length($portion_2), length($context));
                    
                    $portion_2 = '';
                }
            }
            $portion_2 = _chop_last_str($portion_2, 1);
            print ("portion_2 = $portion_2 -- ".length($portion_2)." \n") if ($self->{'debug'} > 3);
            
        }
        # if not find --> cut 1 char --> back to l1
#        print ("Portion not found, strip '", substr($context, 0, 1), "'\n") unless ($p2_hit);
        $context = substr($context, 1, length($context)) unless ($p2_hit);
#        exit;
    }
    
    my $t_result = {
        vsm => {
                id      => $vsm_id,
                keyword => $vsm_keyword,
            },
        token => {
                id      => \@result_ids,
                keyword => \@result_keywords,
            }
    };
    
    return $t_result;
}

sub _chop_last_str {
    my($strin, $l) = @_;
    
    my $str_l = length($strin);
    
    my $chop_l = 0;
    
    if ($str_l >= $l) {
        $chop_l = $str_l - $l;
    } else {
        return '';
    }
    
    return substr($strin, 0, $chop_l);
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



1;

__END__

=head1 AUTHOR

Dong Charsombut <<dong@abctech-thailand.com>>
