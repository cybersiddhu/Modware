use Test::More qw/no_plan/;
use Test::Exception;
use aliased 'Modware::DataSource::Chado';
use Modware::Build;

my $build = Modware::Build->current;
Chado->connect( $build->connect_hash );

use_ok('Modware::Chado::Db');
use_ok('Modware::Chado::Dbxref');

my $db = Modware::Chado::Db->create(
    name        => 'modware',
    url         => 'http://modware.org',
    description => 'modware database somewhere in the world'
);

$db->dbxref( Modware::Chado::Dbxref->new( accession => 'Mod2345' ) );
$db->dbxref( Modware::Chado::Dbxref->new( accession => 'Fbg4839' ) );
is( $db2->dbxref->size, 0,
    'Associated objects are not saved with unsaved parent object' );

my $db2;
lives_ok { $db2 = $db->save } 'It can save with has_many association';
is( $db2->dbxref->size, 2,
    'It has saved and return the number of associated objects' );
isa_ok( $_, 'Modware::Chado::Dbxref' ) for $db2->dbxref;
is_deeply( [ sort { $a cmp $b } map { $_->accession } $db2->dbxref ],
    [qw/Fbg4839 Mod2345/], 'It returns all the saved associated objects' );

my $itr = $db2->dbxref;
isa_ok( $itr, 'Modware::Iterator::Chado::BCS::Association' );
while ( my $dbxref = $itr->next ) {
    isa_ok( $dbxref, 'Modware::Chado::Dbxref' );
}

dies_ok {
    Modware::Chado::Db->create( name => 'mitodb' )
        ->dbxref->add_new( accession => 'Mt438' );
}
'Cannot add association to a unsaved parent object through the add_new method';
my $dbxref2
    = $db2->dbxref->add_new( accession => 'Wb4538943', version => '1.0' );
isa_ok( $dbxref2, 'Modware::Chado::Dbxref' );
is($dbxref2->new_record,  1,  'Associated object is not saved yet');
lives_ok{$db2->save} 'It updates with another associated object';
is($dbxref2->dbxref->size,  3,  'Associated object is also saved in the database');

my $dbxref3 = $db2->dbxref->create(accession => 'NP_4394839');
isnt($dbxref3->new_record,  1,  'Associated object is saved with create method');
is($db2->dbxref->size,  4,  'Parent object confirms the added association');

END {
	$db2->dbrow->delete;
};
