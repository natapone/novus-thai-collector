#!/usr/local/bin/perl -w
use utf8;
use Getopt::Long;
use Data::Dumper;
use Encode qw(decode encode);
use POSIX qw(tmpnam);
use FindBin qw($Bin);
use Try::Tiny;

use NPC::Semantic::Dictionary;


&getSourceFiles(@ARGV);

if ($#sourceFiles == -1)
{
    print STDERR "No input (SOURCE) file supplied!\n";
    askHelp();
    exit;
}


foreach $source (@sourceFiles) {

    open( SRC, "$source" ) || die "Cant open SOURCE file $source, quitting";
        foreach (<SRC>) {
            my $keyword = _clean_keyword($_);
            try {
                print "keyword = '$keyword' ";
            
                my $insert_keyword = NPC::Semantic::Dictionary->model('DBWD::Keyword')->find_or_create( { #insert to Keyword
                    name       => $keyword,
                }, {
                    key => 'keyword_name_key'
                });
                
                print " id = ".$insert_keyword->id." \n";
                
            } catch {
                warn "failed: " . $keyword;
            }
            
            
        }


    close SRC;
    
    
}

sub _trim {
    my($strin) = @_;
    $strin =~ s/^\s+//;
    $strin =~ s/\s+$//;

    return $strin;
}

sub _clean_keyword {
    my($content) = @_;
    $content = _trim($content);
    
    # lower case
    $content = lc($content);
    
    # Single space
    $content =~ s/\s+/ /g;
    
    return $content;
}

sub getSourceFiles
{
    # get the next commandline string...
    my $nextString = shift;
    $index = 0;
    
    while ( $nextString )
    {
        if ( !( -e $nextString ) )
        {
            # file doesn't exist... ignore!
	    
            if ( defined $opt_verbose ) { print "File $nextString does not exist!\n"; }
            $nextString = shift;
            next;
        }
	
    	if ( !( -r $nextString ) )
    	{
            # file can't be read... ignore!
            if ( defined $opt_verbose ) { print "File $nextString cant be read!\n"; }
            $nextString = shift;
            next;
    	}
    	
        if ( -d $nextString )
        {
            # this is a directory, go and search this directory for text files
            &directorySearch( $nextString );
            $nextString = shift;
            next;
        }
	
        if ( !( -T $nextString ) )
        {
            # file is not a text file... ignore!
            if ( defined $opt_verbose ) { print "$nextString is not a text file!\n"; }   
            $nextString = shift; 		
            next;
        }
	
        $sourceFiles[$index] = $nextString; 
        $index++;
        $nextString = shift;
    }
}
