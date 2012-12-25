use 5.014002;
use ExtUtils::MakeMaker;

require Try::Tiny;
require WWW::Curl::Simple;


# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'novus::thai::collector',
    VERSION_FROM      => 'lib/novus/thai/collector.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/novus/thai/collector.pm', # retrieve abstract from module
       AUTHOR         => 'Dong <dong@>') : ()),
);
