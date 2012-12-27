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
use File::Copy;

use novus::thai::utils;
use novus::thai::schema;

my $config = novus::thai::utils->get_config();
our $schema = novus::thai::schema->connect(
                                $config->{connect_info}[0], 
                                $config->{connect_info}[1], 
                                $config->{connect_info}[2], 
                                $config->{connect_info}[3], 
                                );

my $directory = '/home/dong/src/NPC/novus_thai_data';
opendir (DIR, $directory) or die $!;

while (my $file = readdir(DIR)) {
    # Use a regular expression to ignore files beginning with a period
    next if ($file =~ m/^\./);
    next if ($file =~ m/^backup/);
    next if ($file =~ m/^error/);
    
    _read_feed($directory, $file);
}

closedir(DIR);

sub _read_thumbnail {
    my ($thumbnail) = @_;
    my $img = {};
    
    $img->{'src'}   = $thumbnail;
    if ($img->{'src'} =~ /jpg$/i ) {
        $img->{'type'} = 'image/jpeg';
    }
    
    return $img;
}

sub _read_enclosure {
    my ($enclosure) = @_;
    my $img = {};
    
    if ($enclosure) {
        if ( ref($enclosure) eq 'HASH') {
            $img->{'src'}   = $enclosure->{'-url'};
            $img->{'type'}  = $enclosure->{'-type'};
        } elsif ( ref($enclosure) eq 'ARRAY') {
            # Should return array of images !!!
            foreach(@$enclosure) {
                $img->{'src'}   = $_->{'-url'};
                $img->{'type'}  = $_->{'-type'};
            }
        }
    }
    return $img;
}


sub _read_html_text {
    my ($html) = @_;
    return if(!defined($html));
    
    if (ref($html)) {
#        warn "Input text is a reference.\n";
        return "";
    }
    
    my $hs         = HTML::Strip->new();
    my $clean_text = $hs->parse( $html );
    $clean_text = novus::thai::utils->trim($clean_text);
    $hs->eof;
    
    # fix invalid byte sequence for encoding "UTF8"
    $clean_text = decode_utf8($clean_text);
    
    return $clean_text;
}

sub _read_html_image {
    my ($html) = @_;
    
    return if(!defined($html));
    
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
                
                if ($img_style) {
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
            };
            
            if (defined($img)) {
                #remove px unit
                if (defined($img->{'width'})) {
                    if($img->{'width'} =~ /(\d+)px$/i) {
                        $img->{'width'} = $1;
                    }
                }
                if (defined($img->{'height'})) {
                    if($img->{'height'} =~ /(\d+)px$/i) {
                        $img->{'height'} = $1;
                    }
                }
                
                # filter out dot
                if (
                        (defined($img->{'width'}) and $img->{'width'} > 1)
                        or 
                        (defined($img->{'height'}) and $img->{'height'} > 1)
                    ) {
                    push (@images, $img);
                }
                
                
                
            }
            
        }
    }
    
    if (@images) {
        return @images;
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
    
    my $feed_read;
    try {
        $feed_read = XML::FeedPP->new($path);
    } catch {
        warn "caught error: $_"; # not $@
        
        # move file
        move($directory."/".$file, $directory."/error/".$file);
        return;
    };
    
    return if (!defined($feed_read));
    
    my $feed_lastupdate = $feed_read->get('pubDate'); # use pubDate or lastBuildDate or scrape time from file name
    $feed_lastupdate = $feed_read->get('lastBuildDate') if (!defined($feed_lastupdate));
    $feed_timestamp  = $tmp_feed_timestamp if (!defined($feed_lastupdate));
    $feed_timestamp = novus::thai::utils->string_to_timestamp($feed_lastupdate) if (!defined($feed_timestamp));
    
#    print "feed pubDate: ", $feed_lastupdate, " timestamp = ", $feed_timestamp,"\n";
    
    # read feed's item
    my $item_count = 0;
    
    foreach my $item ( $feed_read->get_item() ) {
        my ($itemid, $item_title, $item_link, $item_desc, $item_pubdate, $item_category, $item_author, $item_timestamp, $item_enclosure, $item_thumbnail);
        
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
        push(@medias, $item_enclosure) if(defined($item_enclosure));
        
        $item_thumbnail = _read_thumbnail($item->{'thumb'}) if $item->{'thumb'};
        
        # Should have separate table to store medias from feed
        my $media_src='';
        foreach (@medias) {
            if ($_) {
                $media_src = $_->{'src'};
            }
        }
        
#        print "\n";
#        print "URL: ".$item_link."\n";
#        print "Feed id: ", $feed_id, "\n";
#        print "Title: ".$item_title."\n";
#        print "Desc: ".$item_desc."\n";
#        print "Date: ",$item_pubdate," \n";
#        print "timestamp: ",$item_timestamp,"\n";
#        print "Category: ";
#        print $item_category if ($item_category);
#        print "\n";
#        print "Author: ";
#        print $item_author if ($item_author);
#        print "\n";
#        print "Media: $media_src \n";
#        print "+++++++++++++++++++++++++++++++ \n";
                
        #Insert to Item
        if ($item_link) {
            my $i_updated = $schema->resultset('Item')->update_or_create(
                            {
                                feedid      => $feed_id,
                                title       => $item_title,
                                link        => $item_link,
                                description => $item_desc,
                                pubdate     => $item_pubdate,
                                category    => $item_category,
                                author      => $item_author,
                                timestamp   => $item_timestamp,
                                media       => $media_src,
                            }, { key   => 'item_link_key' }
            );
            print $i_updated->id, ": ", encode_utf8($i_updated->title)." -----@ $item_pubdate\n";
        } else {
            print "*** missing link! ==> $item_title -----@ $item_pubdate\n";
        }
    }
    print "--------- \n";
    
    # move file
    move($directory."/".$file, $directory."/backup/".$file);
}


