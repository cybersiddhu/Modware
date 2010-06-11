use strict;
use Test::More qw/no_plan/;  
use Path::Class::Dir;
use FindBin qw/$Bin $Script/;


use_ok('ModwareX::DataSource::Chado');


#now get some temporary sqlite database being setup
my $tmp1 = Path::Class::Dir->new($Bin)->parent->subdir('tmp')->file('test1.sqlite')->stringify;
my $tmp2 = Path::Class::Dir->new($Bin)->parent->subdir('tmp')->file('test2.sqlite')->stringify;


#default one sqlite3 file based
ModwareX::DataSource::Chado->connect(
	dsn => "dbi:SQLite:dbname=$tmp1"
);

my $handler = ModwareX::DataSource::Chado->handler;
isa_ok($handler, 'Bio::Chado::Schema');


ModwareX::DataSource::Chado->connect(
	dsn => "dbi:SQLite:dbname=$tmp2", 
	source_name => 'beermod'
);

my $handler2 = ModwareX::DataSource::Chado->handler('beermod');
isa_ok($handler2, 'Bio::Chado::Schema');

unlink ($tmp1, $tmp2);



