use Test::More qw/no_plan/;
use Test::Exception;
use aliased 'Modware::DataSource::Chado';
use Modware::Build;
use Data::Dump qw/pp/;

{

    package MyOrganism;
    use Modware::Chado;

    bcs_resultset 'Organism::Organism';

    chado_has 'abbreviation';
    chado_has 'species';
    chado_has 'organism_id' => ( primary => 1);
    chado_has 'genus' => ( lazy => 1 );
    chado_has 'name' => ( column => 'common_name' );

}

{

    package MyStock;
    use Modware::Chado;

    bcs_resultset 'Stock::Stock';

    chado_has 'stock_id' => ( primary => 1 );
    chado_has 'uniquename';
    chado_has 'stock_name' => ( column => 'name' );
    chado_type 'stock_type' =>
        ( db => 'Stock', cv => 'Modware-publication-publication', lazy => 1 );
    chado_has 'organism_id';
    chado_property 'status' => (
        db     => 'Stock',
        cv     => 'Modware-publication-publication',
        lazy   => 1,
        cvterm => 'stock_term'
    );
    chado_multi_properties 'shipped_to' => (
        db     => 'Stock',
        cv     => 'Modware-publication-publication',
        lazy   => 1,
        cvterm => 'stock_location'
    );

    chado_secondary_dbxref 'accession' => (
        db      => 'modr',
        version => 1
    );
    chado_secondary_dbxref 'uniprot' => (
        db => 'swissprot',
        lazy => 1
    );
    chado_multi_dbxrefs 'external_ids' => ( db => 'affy' );
}

my $build = Modware::Build->current;
Chado->connect( $build->connect_hash );

my $org = new_ok('MyOrganism');
$org->abbreviation('D.Pulex');
$org->genus('Daphnia');
$org->species('pulex');
$org->name('water fleas');
is( $org->meta->bcs_resultset, 'Organism::Organism',
    'Got the value of bcs resultset' );



my $new_org;
lives_ok { $new_org = $org->save } 'It creates a new record for organism';
like( $new_org->organism_id, qr/\d+/,
    'It has the new organism id from database' );
isnt( $new_org->has_genus, 1, 'genus attribute is empty now' );
is( $new_org->genus,   'Daphnia', 'genus attribute is lazily loaded' );
is( $new_org->species, 'pulex',   'got the species value from database' );

my $stock = MyStock->new(
    uniquename => 'daphnia',
    stock_name => 'dstock',
    stock_type => 'wild'
);
$stock->organism_id( $new_org->organism_id );
$stock->status('live');
$stock->shipped_to( [ 'malayasia', 'sudan' ] );

my $db_stock;
lives_ok { $db_stock = $stock->save } 'It creates a new stock';
is( $db_stock->uniquename, $stock->uniquename, 'It matches the uniquename' );
is( $db_stock->stock_name, $stock->stock_name, 'It matches the uniquename' );
is( $db_stock->stock_type, $stock->stock_type, 'It matches the stock_type' );
isnt( $db_stock->has_status, 1, 'status attribute is lazily loaded' );
is( $db_stock->status, $stock->status, 'It matches the stock status' );
is_deeply( $db_stock->shipped_to, $stock->shipped_to,
    'It matches the shipment locations' );

my $another_stock = MyStock->new(
    uniquename  => 'drosophila',
    stock_type  => 'mutant',
    organism_id => $new_org->organism_id
);

$another_stock->accession('X4567');
$another_stock->uniprot('P45678');
$another_stock->external_ids( [ 'XP_439834', 'NM_43894389' ] );
my $db_stock2;
lives_ok { $db_stock2 = $another_stock->save }
'It creates a another new stock with uniquename and type';
isnt( $db_stock2->stock_name, 1, 'It does not have a stock name' );
is( $db_stock2->uniquename, $another_stock->uniquename,
    'It does have a uniquename' );
is( $db_stock2->stock_type, $another_stock->stock_type,
    'It does have a stock type' );
isnt( $db_stock2->has_uniprot, 1, 'uniprot will be lazily loaded' );
is( $db_stock2->uniprot, $another_stock->uniprot, 'mathces uniprot from db' );
is( $db_stock2->accession, $another_stock->accession,
'mathces accession from db' );
is_deeply(
    $db_stock2->external_ids,
    $another_stock->external_ids,
    'mathces external ids from db'
);

END {
    $new_org->dbrow->delete;
    $db_stock->dbrow->delete;
    $db_stock2->dbrow->delete;
}
