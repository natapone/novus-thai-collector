use inc::Module::Install;

name 'novus-thai-collector';
all_from 'lib/novus/thai/collector.pm';

requires 'novus::thai::schema';
requires 'novus::thai::utils';
requires 'Lingua::Model::Ngram';

requires 'Moose';
requires 'Encode';
requires 'Storable';
requires 'Data::Dumper';
requires 'Exporter';

test_requires 'DBD::SQLite';
test_requires 'DateTime::Format::SQLite';

install_script glob('bin/*');
auto_install;

WriteAll;

