use Test::More qw/no_plan/;
use aliased 'Modware::DataSource::Chado';
use aliased 'Modware::Chado::Query::BCS::Publication';
use Modware::Build;

BEGIN {
    use_ok('Modware::Chado::Query::BCS::Publication');
}

my $build = Modware::Build->current;
Chado->connect(
    dsn      => $build->config_data('dsn'),
    user     => $build->config_data('user'),
    password => $build->config_data('password')
);

my $itr = Publication->search( author => 'Ian' );
isa_ok( $itr, 'Modware::Collection::Iterator::BCS::ResultSet' );
is( $itr->count, 3, 'it can search publications with author name' );
is( Publication->count( author => 'Ian' ),
    3, 'it can search no of publications by an author' );
is( Publication->count( journal => 'PloS' ),
    2, 'it can count publications by journal name' );

my $pub = Publication->find_by_pubmed_id(20830294);
isa_ok($pub,  'Modware::Publication');

my $pub2 = Publication->find($pub->dbrow->pub_id);
isa_ok($pub2,  'Modware::Publication');
