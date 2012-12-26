#!/usr/local/bin/perl -w
use novus::thai::schema;
use novus::thai::utils;

use MediaWiki::DumpFile;
use Data::Dumper;
use Encode qw(:all);


#my $filename = "/home/dong/Downloads/thwiki-20121123-pages-articles.xml";
my $filename = "/home/dong/Downloads/thwiktionary-20121202-pages-articles.xml";

$mw = MediaWiki::DumpFile->new;
$pages = $mw->pages($filename);

# init DB
my $config = novus::thai::utils->get_config();
my $schema = novus::thai::schema->connect(
                                $config->{connect_info}[0], 
                                $config->{connect_info}[1], 
                                $config->{connect_info}[2], 
                                $config->{connect_info}[3], 
                                );

my $keywords = $schema->resultset('Keyword');

my $page_count=0;
my $dict_count=0;

while(defined($page = $pages->next)) {
    my $page_title = $page->title;
    
    if ($page_title !~ /\:/) {
#        print "Title == ", encode_utf8($page_title) , "  l=", length($page_title) ;
        $page_count++;
        
        
#        my $kk = $keywords->search( {  name => $page_title} )->first;
#        if ($kk) {
#            print "    found! id = ",$kk->id, "\n";
#            $dict_count++;
#        } else {
#            print "\n";
#        }
        
        my $result = $keywords->find_or_create(
                        {
                            name   => $page_title,
                            length => length($page_title),
                        }, { key   => 'keyword_name_key' }
        );
        print encode_utf8($page_title), " --> Create ", $result->id, ": ", $result->name, " length = ", $result->length ,"\n";
        
    }
    
    
#    exit if ($page_count>200);
#    print "===================\n";
}

print "Pages count = $page_count \n";
#print "In DB = $dict_count \n";

