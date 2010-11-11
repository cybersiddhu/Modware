use strict;
use Test::More qw/no_plan/;
use Test::Exception;
use aliased 'Modware::DataSource::Chado';
use Modware::Build;

BEGIN {
    use_ok('Modware::Publication::JournalArticle');
}

my $build = Modware::Build->current;
Chado->connect( $build->connect_hash );

my $test_cv = 'Modware-publication-pub_type';
my $Pub     = 'Modware::Publication::JournalArticle';

my $pub = $Pub->new( year => 2004 );
$pub->title('The best title ever');
$pub->abstract('One of the best abstract ever');
$pub->status('unpublished');
$pub->cv($test_cv);
$pub->add_author( { first_name => 'Mumbo', last_name => 'Jumbo' } );

dies_ok { $pub->create }
'It cannot create record without setting journal name';

$pub->journal('Modware journal');
lives_ok { $pub->create }
'It needs a author and journal names to create a new record';

#lets find the record with our cool search API
is( $Pub->count( title => 'Best title', year => 2004, journal => 'Modware' ),
    1,
    'has got one persisted record from database'
);

my ($pub_from_db) = $Pub->search(
    title   => '*Best title*',
    year    => 2004,
    journal => 'Modware'
);
is( $pub_from_db->title, $pub->title, 'persisted record matches in title' );
is( $pub_from_db->journal, $pub->journal,
    'persisted record matches in journal name' );
is( $pub_from_db->status, $pub->status,
    'persisted record matches in status' );
is( $pub_from_db->total_authors, 1, 'has got one author' );

my $author = $pub_from_db->get_from_authors(0);
isa_ok( $author, 'Modware::Publication::Author' );
is( $author->first_name,, 'Mumbo', 'has got author first name' );

$pub_from_db->delete( { cascade => 1 } );
is( $Pub->count( title => 'Best title', year => 2004, journal => 'Modware' ),
    0,
    'got no record from database after deletion'
);

#another new record
$pub = $Pub->new(
    year     => 2010,
    title    => 'My title',
    abstract => 'My best abstract',
    status   => 'In press',
    cv       => $test_cv,
    journal  => 'Hideous journal'
);
$pub->add_author(
    {   first_name => 'James',
        last_name  => 'Brown',
        suffix     => 'Sr.',
        initials   => 'King'

    }
);
$pub->add_author(
    {   first_name => 'Tucker',
        last_name  => 'Brown',
        initials   => 'Mr.'
    }
);

lives_ok { $pub->create } 'create another new publication record';
is( $Pub->count( year => '2010' ), 6, 'got six publications from database' );

($pub_from_db) = $Pub->search(
    year    => '2010',
    title   => '*mitochondria*',
    journal => 'Ophthalmic'
);

is( $pub_from_db->journal,
    'Ophthalmic research',
    'got back the journal name from database'
);

#now lets update and then do a round trip
$pub_from_db->journal('My journal');
$pub_from_db->year(2009);
$pub_from_db->title('Revoked title');
$pub_from_db->issn('12354-748');
$pub_from_db->issue(76);
$pub_from_db->status('underpublished');

lives_ok { $pub_from_db->update } 'updated one publication record';

my $pub_after_update = $Pub->find( $pub_from_db->dbrow->pub_id );
is( $pub_after_update->journal, $pub_from_db->journal,
    'journal name matches after update' );
is( $pub_after_update->year, $pub_from_db->year,
    'journal year matches after update' );
is( $pub_after_update->title, $pub_from_db->title,
    'journal title matches after update' );
is( $pub_after_update->issue, $pub_from_db->issue,
    'journal issue matches after update' );
is( $pub_after_update->issn, $pub_from_db->issn,
    'journal issn matches after update' );
