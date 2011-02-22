use Test::More qw/no_plan/;
use Test::Exception;
use aliased 'Modware::DataSource::Chado';
use Modware::Build;
use Data::Dump qw/pp/;

{

    package MyStock;
    use Modware::Chado;

    bcs_resultset 'Stock::Stock';

    chado_has 'stock_id' => ( primary => 1 );
    chado_has 'uniquename';
    chado_has 'stock_name' => ( column => 'name' );
    chado_dbxref 'id' => ( db => 'Stock', lazy => 1 );
    chado_type 'stock_type' =>
        ( db => 'Stock', cv => 'Modware-publication-publication' );
    chado_property 'status' => (
        db     => 'Stock',
        cv     => 'Modware-publication-publication',
        cvterm => 'stock_term',
        lazy   => 1
    );

    chado_belongs_to 'organism' => ( class => 'Modware::Chado::Organism' );
}

my $build = Modware::Build->current;
Chado->connect( $build->connect_hash );

my $org = new_ok('Modware::Chado::Organism');
$org->abbreviation('D.Pulex');
$org->genus('Daphnia');
$org->species('pulex');
$org->name('water fleas');

my $stock = MyStock->new(
    uniquename => 'daphnia',
    stock_name => 'dstock',
    id         => 'D2345',
    stock_type => 'wild'
);

is( $stock->meta->has_method($_), 1, "stock object has $_ method installed" )
    for qw/organism create_organism new_organism/;

$stock->status('live');
$stock->organism($org);

my $db_stock;
lives_ok { $db_stock = $stock->save } 'It creates a new stock';
is( $db_stock->uniquename, $stock->uniquename, 'It matches the uniquename' );
is( $db_stock->stock_name, $stock->stock_name, 'It matches the stock name' );
is( $db_stock->id,         $stock->id,         'It matches the id' );
isnt( $db_stock->has_status, 1, 'status attribute is lazily loaded' );
is( $db_stock->status, $stock->status, 'It matches the stock status' );

my $db_org = $db_stock->organism;
isa_ok( $db_org, 'Modware::Chado::Organism' );
is( $db_org->abbreviation, $org->abbreviation,
    'related organism matches abbreviation' );
is( $db_org->genus,   $org->genus,   'related organism matches genus' );
is( $db_org->species, $org->species, 'related organism matches species' );

#### --- update tests ------- ###

$db_stock->id('P574393');
$db_stock->stock_name('bacula');
lives_ok { $db_stock->update } 'It updates the existing parent object and internal related objects';
is ($db_stock->stock_name,  $db_stock->dbrow->name,  'It matches the name from updated parent object');
is( $db_stock->id,
    $db_stock->_id->accession,
    'It matches the dbxref from updated parent object'
);

dies_ok {
    MyStock->new( uniquename => 'bacillus', stock_type => 'mutant' )->update;
}
'It cannot update non-persistent object';

$db_org->species('colitis');
$db_org->name('ecoli');
$db_org->abbreviation('E.coli');
$db_org->genus('Escherichia');
$db_stock->stock_name('E.coli');
$db_stock->uniquename('E.coli');
$db_stock->organism($db_org);

lives_ok { $db_stock->update }
'It updates the existing parent and related objects';
is( $db_stock->dbrow->name, $db_stock->stock_name,
    'It matches the added stock_name' );
is( $db_stock->dbrow->uniquename,
    $db_stock->uniquename, 'It matches the updated uniquename' );
my $org_up = $db_stock->organism;
isa_ok( $org_up, 'Modware::Chado::Organism' );
is( $org_up->genus, $db_org->genus,
    'It matches the updated genus from updated related object' );
is( $org_up->species, $db_org->species,
    'It matches the updated species from updated related object' );
is( $org_up->name, $db_org->name,
    'It matches the updated name from updated related object' );
is( $org_up->abbreviation, $db_org->abbreviation,
    'It matches the added abbreviation from updated related object' );

END {
    $db_stock->dbrow->delete;
    $org_up->dbrow->delete;
}
