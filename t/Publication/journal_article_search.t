use Test::Most qw/no_plan die/;
use aliased 'Modware::DataSource::Chado';
use Modware::Build;

BEGIN {
    use_ok('Modware::Chado::Query::BCS::Publication::JournalArticle');
}


my $build = Modware::Build->current;
Chado->connect(
    dsn      => $build->config_data('dsn') ,
    user     => $build->config_data('user'),
    password => $build->config_data('password')
);

#Chado->handler->storage->debug(1);

my $Pub = 'Modware::Chado::Query::BCS::Publication::JournalArticle';
my $pub_itr = $Pub->search( journal => 'Text' );
isa_ok( $pub_itr, 'Modware::Collection::Iterator::BCS::ResultSet' );
is( $pub_itr->count, 3,
    'has journal articles with partial match in journal name' );
is($Pub->count(journal => 'Text'),  3,  'has journal articles from direct counting');

$pub_itr = $Pub->search(
    journal => 'Text7',
    cond    => { match => 'exact' }
);
is( $pub_itr->count, 1,
    'has journal article with exact match in journal name' );

$pub_itr = $Pub->search( journal => 'none', );
is( $pub_itr->count, 0, 'has  no match with non-existing journal name' );

$pub_itr = $Pub->search(
    title => 'Text503',
    cond  => { match => 'exact' }
);
is( $pub_itr->count, 1,
    'has journal article with exact match in title field' );

$pub_itr = $Pub->search( title => '5', );
is( $pub_itr->count, 3,
    'has journal articles with partial match in title field' );

$pub_itr = $Pub->search( author => 'Text2', );
is( $pub_itr->count, 2,
    'has  journal articles with partial match in author name' );

$pub_itr = $Pub->search(
    author => 'Text510',
    cond   => { match => 'exact' }
);
is( $pub_itr->count, 1,
    'has journal article with exact match in author name' );

$pub_itr = $Pub->search( journal => 'Text', author => 'Text' );
is( $pub_itr->count, 3,
    'has journal articles with partial matches in author and journal names' );

$pub_itr = $Pub->search(
    journal => 'Text7',
    author   => 'Text21',
    cond    => { match => 'exact' }
);
is( $pub_itr->count, 1,
    'has journal articles with exact matches in author and journal names' );


$pub_itr = $Pub->search( journal => '5', title => '5' );
is( $pub_itr->count, 2,
    'has journal articles with partial matches in journal and title fields' );

$pub_itr = $Pub->search(
    journal => 'Text7',
    title   => 'Text9',
    cond    => { match => 'exact' }
);
is( $pub_itr->count, 1,
    'has journal articles with exact matches in journal and title fields' );

$pub_itr = $Pub->search(
    journal => 'Text7',
    title   => 'none', 
    cond    => { clause => 'OR' }
);
is( $pub_itr->count, 1,
    'has journal articles with exact matches in journal and title fields' );

