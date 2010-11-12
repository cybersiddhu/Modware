use Test::More qw/no_plan/;
use aliased 'Modware::DataSource::Chado';
use Modware::Build;

BEGIN {
    use_ok('Modware::Chado::Query::BCS::Publication::Pubmed');
}

my $build = Modware::Build->current;
Chado->connect( $build->connect_hash );

my $sql_type = ucfirst lc( Chado->handler->storage->sqlt_type );

my $Pub = 'Modware::Chado::Query::BCS::Publication::Pubmed';
is( $Pub->count( journal => '*PloS*' ),
    2, 'it can count publications by journal name' );
my $itr = $Pub->search( author => '*Ian*' );
isa_ok( $itr, 'Modware::Collection::Iterator::BCS::ResultSet' );
is( $itr->count, 3, 'it can search publications with author name' );
is( $Pub->count( author => '*Ian*' ),
    3, 'it can search no of publications by an author' );

my $pub = $Pub->find_by_pubmed_id(20830294);
isa_ok( $pub, 'Modware::Publication::Pubmed' );

my $pub2 = $Pub->find( $pub->dbrow->pub_id );
isa_ok( $pub2, 'Modware::Publication::Pubmed' );

is( $Pub->count( status => '*Review*' ),
    4, 'has publication with review status' );

SKIP: {

    skip 'oracle do not support *=* search', 1 if $sql_type eq 'Oracle';

    is( $Pub->search( last_name => 'Lewin*', first_name => 'AS Alfred S' )
            ->count,
        1,
        'has publication from first and last name search'
    );

    is( $Pub->count( status => 'In-Process' ),
        3, 'has publication with In-Process status' );

}

SKIP: {
    skip "full text search with oracle engine is supported only", 1
        if $sql_type ne 'Oracle';

    #is( $Pub->count( status => '*Process*', cond => { full_text => 1 } ),
    #    3, 'got publication after full text search' );

    is( $Pub->search( author => '*Ian*', cond => { full_text => 1 } )->count,
        3,
        'got publication after full text search on author fields'
    );
}

