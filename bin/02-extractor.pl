#!/usr/local/bin/perl -w
use lib "/home/dong/src/lib/perl5";
use lib "/home/dong/src/NPC/novus-thai-collector/lib";
use lib "/home/dong/src/NPC/novus-thai-schema/lib";
use lib "/home/dong/src/NPC/novus-thai-utils/lib";

use strict;
use warnings;
use XML::FeedPP;
use Data::Dumper;
use Encode;
use HTML::TreeBuilder;
use HTML::Strip;
use Try::Tiny;

use novus::thai::utils;

my $directory = '/home/dong/src/NPC/novus_thai_data';
opendir (DIR, $directory) or die $!;

while (my $file = readdir(DIR)) {
    # Use a regular expression to ignore files beginning with a period
    next if ($file =~ m/^\./);
    
    _read_feed($directory, $file);
}

closedir(DIR);

sub _read_enclosure {
    my ($enclosure) = @_;
    
    my $img = {};
            
    $img->{'src'}   = $enclosure->{'-url'};
    $img->{'type'}  = $enclosure->{'-type'};
    
    return $img;
}


sub _read_html_text {
    my ($html) = @_;
    
    $html = decode_utf8($html);
    my $hs         = HTML::Strip->new();
    my $clean_text = $hs->parse( $html );
    $clean_text = novus::thai::utils->trim($clean_text);
    $hs->eof;
    
    return $clean_text;
}

sub _read_html_image {
    my ($html) = @_;
    
    $html = decode_utf8($html);
    
    my $tree = HTML::TreeBuilder->new;
    $tree->parse($html);
    my @elements = $tree->find('img');
    
    my @images = ();
    foreach my $element (@elements) { 
        my ($img_src, $img_w, $img_h);
        
        if ($element->{'src'}) {
            my $img = {};
            
            $img->{'src'}    = $element->{'src'};
            $img->{'width'}  = $element->{'width'};
            $img->{'height'} = $element->{'height'};
            
            if ($img->{'src'} =~ /jpg$/i ) {
                $img->{'type'} = 'image/jpeg';
            } elsif ($img->{'src'} =~ /png$/i) {
                $img->{'type'} = 'image/png';
            }
            
            # get width x height from style if they're not defined in attributes'
            if (!defined($img_w) and !defined($img_h)) {
                my $img_style = $element->{'style'};

                try {
                    $img_style =~ s/\s+//g;
                    $img_style =~ s/\-/\_/g;
                    $img_style =~ s/\;/\'\,/g;
                    $img_style =~ s/\:/\=\>\'/g;
                    my %styles = eval "($img_style)";

                    $img->{'width'}  = $styles{'width'};
                    $img->{'height'} = $styles{'height'};
                    
                } catch {
                    warn "Wrong style format: ".$img_style; # not $@
                };
            }
            push (@images, $img);
        }
    }
    
    if (@images) {
        return \@images;
    } else {
        return;
    }
    
    
}

sub _read_feed {
    my ($directory, $file) = @_;
    
    my $path = $directory."/".$file;
    my $feed_timestamp;
    my $tmp_feed_timestamp; 
    my $feed_id;
    
    print "start read feed ==> $path \n";
    
    if ($file =~ /T(\d+)F(\d+)\.xml/) {
            
            $tmp_feed_timestamp = $1;
            $feed_id = $2;
        }
    
    my $feed_read = XML::FeedPP->new($path);
    
    my $feed_lastupdate = $feed_read->get('pubDate'); # use pubDate or lastBuildDate or scrape time from file name
    $feed_lastupdate = $feed_read->get('lastBuildDate') if (!defined($feed_lastupdate));
    $feed_timestamp  = $tmp_feed_timestamp if (!defined($feed_lastupdate));
    
    $feed_timestamp = novus::thai::utils->string_to_timestamp($feed_lastupdate) if (!defined($feed_timestamp));
    
    print "feed pubDate: ", $feed_lastupdate, " timestamp = ", $feed_timestamp,"\n";
    
    # read feed's item
    my $item_count = 0;
    
    foreach my $item ( $feed_read->get_item() ) {
        my ($itemid, $item_title, $item_link, $item_desc, $item_pubdate, $item_category, $item_author, $item_timestamp, $item_enclosure);
        
        $item_count++;
        $item_desc = $item->description();
        my @medias = _read_html_image($item_desc);
        
        $item_title     = _read_html_text($item->title());
        $item_link      = $item->link();
        $item_desc      = _read_html_text($item->description());
        $item_pubdate   = $item->get('pubDate');
        $item_pubdate   = $feed_lastupdate if (!defined($item_pubdate));
        $item_category  = $item->category();
        $item_author    = $item->author();
        $item_timestamp = novus::thai::utils->string_to_timestamp($item_pubdate);
        
        
        $item_enclosure = _read_enclosure($item->{'enclosure'}) if $item->{'enclosure'};
        push(@medias, $item_enclosure);
                print "URL: ".$item_link."\n";
                print "Title: ".$item_title."\n";
                print "Desc: ".$item_desc."\n";
                print "Date: ",$item_pubdate," \n";
                print "timestamp: ",$item_timestamp,"\n";
                print "Category: ";
                print $item_category if ($item_category);
                print "\n";
                print "Author: ";
                print $item_author if ($item_author);
                print "\n";
                print "Media: ", Dumper(\@medias),"\n";
                
        #Insert to FeedItem
#        my $f_updated = NPC::Buzz::Gather->model('DBBZ::FeedItem')->update_or_create( {
##                    itemid      => $itemid,
#            feedid      => $feed->feedid,
#            title       => $item_title,
#            link        => $item_link,
#            description => $item_desc,
#            pubdate     => $item_pubdate,
#            category    => $item_category,
#            author      => $item_author,
#            timestamp   => $item_timestamp,
#            scrape      => $feed->scrape,
#        },{
#            key => 'feed_item_link_key'
#        });
        
         print "+++++++++++++++++++++++++++++++ \n";
    }
#    
#    print $feed->title." --> update $item_count @ $last_builddate ($last_timestamp)\n";
    
    
    
    print "--------- \n";
}


