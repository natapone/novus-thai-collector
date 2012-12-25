#!/usr/local/bin/perl -w
use lib "/home/dong/src/lib/perl5";
use lib "/home/dong/src/NPC/novus-thai-collector/lib";
use lib "/home/dong/src/NPC/novus-thai-schema/lib";
use lib "/home/dong/src/NPC/novus-thai-utils/lib";

my $sourcefile = 'tdict.txt';

open (MYFILE, "./etc/$sourcefile");
while (<MYFILE>) {
    chomp;
    print "--> $_\n";
}
close (MYFILE); 
