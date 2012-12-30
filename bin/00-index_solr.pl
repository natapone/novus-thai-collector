#!/usr/local/bin/perl -w
 
use strict;
use warnings;
 
use URI;
use WebService::Solr;
use JSON::XS;
use XML::Writer;
use IO::File;
use utf8;
 
use novus::thai::utils;
use novus::thai::schema;
 
my $config = novus::thai::utils->get_config();
my $schema = novus::thai::schema->connect(
                                $config->{connect_info}[0], 
                                $config->{connect_info}[1], 
                                $config->{connect_info}[2], 
                                $config->{connect_info}[3], 
                                );
 
my $news_data = $schema->resultset('Item')->search;
 
#define url data for solr connection
my $url = 'http://localhost:8983/solr';
 
while (my $news = $news_data->next) {
 
    #initial solr webservice
    my $solr = WebService::Solr->new($url);
 
    #define data for indexing
    my @fields = (
        [ id     => $news->id ],
        [ title  => $news->title ],
        [ description => $news->description ],
    );
 
    #initial and define data field for document process
    my @field_objs = map { WebService::Solr::Field->new( @$_ ) } @fields;
 
    #initial document for indexing
    my $doc = WebService::Solr::Document->new;
 
    #push data field into document
    $doc->add_fields(@field_objs);
 
    #add document to solr 
    $solr->add($doc);
 
    #make commit for this document indexing
    $solr->commit;
 
}
 
exit;
