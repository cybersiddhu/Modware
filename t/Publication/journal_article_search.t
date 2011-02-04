use Test::More qw/no_plan/;
use aliased 'Modware::DataSource::Chado';
use Modware::Build;

BEGIN {
    use_ok('Modware::Chado::Query::BCS::Publication::JournalArticle');
}

my $build = Modware::Build->current;
Chado->connect( $build->connect_hash );

my $Pub = 'Modware::Chado::Query::BCS::Publication::JournalArticle';
my $pub_itr = $Pub->search( journal => '*Text*' );
isa_ok( $pub_itr, 'Modware::Collection::Iterator::BCS::ResultSet' );
is( $pub_itr->count, 3,
    'has journal articles with partial match in journal name' );
is( $Pub->count( journal => '*Text*' ),
    3, 'has journal articles from direct counting' );

$pub_itr = $Pub->search( journal => 'Text7', );
is( $pub_itr->count, 1,
    'has journal article with exact match in journal name' );

$pub_itr = $Pub->search( journal => '*none*' );
is( $pub_itr->count, 0, 'has  no match with non-existing journal name' );

$pub_itr = $Pub->search( title => '*5*', );
is( $pub_itr->count, 3,
    'has journal articles with partial match in title field' );

$pub_itr = $Pub->search( author => '*Text2*', );
is( $pub_itr->count, 2,
    'has  journal articles with partial match in author name' );

$pub_itr = $Pub->search( journal => '*5*', title => '*5*' );
is( $pub_itr->count, 2,
    'has journal articles with partial matches in journal and title fields' );

$pub_itr = $Pub->search(
    journal => '*Text7*',
    title   => '*none*',
    cond    => { clause => 'OR' }
);
is( $pub_itr->count, 1,
    'has journal articles with exact matches in journal and title fields' );

is( $Pub->search( last_name => '*Underwood*', first_name => 'MJ Malcolm J' )
        ->count,
    1,
    'has journal articles from first and last name search'
);

is( $Pub->search( last_name => '*Torres*' )->count,
    1, 'has journal articles from last name search' );

$pub_itr = $Pub->search( journal => '*Text*', author => '*Text*' );
is( $pub_itr->count, 3,
    'has journal articles with partial matches in author and journal names' );

my @all_pubs = $Pub->search( journal => '*Text*', author => '*Text*' )
    ->order('year asc');
is( $all_pubs[0]->year, 1999, 'it has the publication after sorted by year in ascending order'
);

@all_pubs = $Pub->search( journal => '*Text*', author => '*Text*' )
    ->order('year desc');
is( $all_pubs[-1]->year, 1999, 'it has the publication after sorted by year in descending order'
);

SKIP: {

    my $sql_type = ucfirst lc( Chado->handler->storage->sqlt_type );
    skip 'oracle do not support *=* search', 5 if $sql_type eq 'Oracle';

    $pub_itr = $Pub->search( title => 'Text503', );

    is( $pub_itr->count, 1,
        'has journal article with exact match in title field' );

    $pub_itr = $Pub->search( author => 'Text510', );
    is( $pub_itr->count, 1,
        'has journal article with exact match in author name' );

    $pub_itr = $Pub->search(
        journal => 'Text7',
        author  => 'Text21',
    );
    is( $pub_itr->count, 1,
        'has journal articles with exact matches in author and journal names'
    );

    $pub_itr = $Pub->search(
        journal => 'Text7',
        title   => 'Text9',
    );
    is( $pub_itr->count, 1,
        'has journal articles with exact matches in journal and title fields'
    );

    is( $Pub->search( first_name => 'GG George G' )->count,
        1, 'has journal articles from last name search' );

}
