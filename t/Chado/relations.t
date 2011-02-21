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
        ( db => 'Stock', cv => 'Modware-publication-publication');
    chado_property 'status' => (
        db     => 'Stock',
        cv     => 'Modware-publication-publication',
        cvterm => 'stock_term', 
        lazy => 1
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
$stock->organism( $org );

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

my $stock2 = MyStock->new(
    uniquename => 'drosophila',
    stock_type => 'mutant',
);
my $org2 = $stock2->new_organism(
    genus   => 'Homo',
    species => 'sapiens',
    name    => 'human'
);
isa_ok( $org2, 'Modware::Chado::Organism' );
my $db_stock2;
lives_ok { $db_stock2 = $stock2->save }
'It can save another stock with new_organism method';
is( $db_stock2->organism->genus,
    $org2->genus, 'It can retrieve related organism with matching genus' );

my $stock3 = MyStock->new(
    uniquename => 'ecoli',
    stock_type => 'wild',
);
my $org3;
lives_ok {
    $org3 = $stock3->create_organism(
        genus   => 'Escherichia',
        species => 'coli'
    );
}
'It can create an associated object';
my $db_stock3;
lives_ok { $db_stock3 = $stock3->save }
'It can create another stock after associating with a new object';
is( $org3->species,
    $db_stock3->organism->species,
    'It matches the species between parent and related object'
);

END {
    $db_stock->dbrow->delete;
    $db_org->dbrow->delete;
    $db_stock2->dbrow->delete;
    $db_stock2->organism->dbrow->delete;
    $org3->dbrow->delete;
    $db_stock3->dbrow->delete;
};
