use strict;
use Test::More qw/no_plan/;
use Test::Exception;
use aliased 'Modware::DataSource::Chado';
use Modware::Build;
use aliased 'Modware::Publication::Author';

BEGIN {
    use_ok('Modware::Publication');
}

my $build = Modware::Build->current;
Chado->connect(
    dsn      => $build->config_data('dsn'),
    user     => $build->config_data('user'),
    password => $build->config_data('password')
);

my $test_cv = 'Modware-publication-pub_type';
my $Pub     = 'Modware::Publication';

my $pub = $Pub->new( year => 2010 );
$pub->title('The title for publication');
$pub->abstract('The abstract that rocked the world');
$pub->status('published');
$pub->cv($test_cv);
$pub->add_author(
    Author->new(
        first_name => 'First man',
        last_name  => 'Last name',
        initials   => 'Mr.'
    )
);
$pub->add_author(
    Author->new(
        first_name => 'Todd',
        last_name  => 'Gagg',
        initials   => 'Mr.'
    )
);
$pub->journal('Hungry man');
dies_ok { $pub->create } 'It cannot create record without pubmed id';

$pub->pubmed_id(7865209);
lives_ok { $pub->create } 'It needs pubmed_id to create a record';

#lets find the record with our cool search API
is( $Pub->count(
        title   => 'publication',
        year    => 2010,
        journal => 'Hungry',
    ),
    1,
    'has got the created publication record from database'
);

my $pub_from_db = $Pub->find_by_pubmed_id(7865209);
is( $pub_from_db->title, $pub->title, 'retrieved record matches in title' );
is( $pub_from_db->journal, $pub->journal,
    'retrieved record matches in journal name' );
is( $pub_from_db->status, $pub->status,
    'retrieved record matches in status' );
is( $pub_from_db->total_authors, 2, 'retrieved record has two authors' );

my $author = $pub_from_db->get_from_authors(0);
isa_ok( $author, 'Modware::Publication::Author' );

$pub_from_db->delete( { cascade => 1 } );
is( $Pub->count(
        title   => 'publication',
        year    => 2010,
        journal => 'Hungry',
        author  => 'Todd'
    ),
    0,
    'got no record from database after deletion'
);

#another new record
$pub = $Pub->new(
    year      => 2050,
    title     => 'Single malt whisky',
    abstract  => 'Drink up!',
    status    => 'In press',
    cv        => $test_cv,
    journal   => 'Liquid journal',
    pubmed_id => 420
);
$pub->add_author(
    {   first_name => 'Harry',
        last_name  => 'Potter',
        suffix     => 'Sr.',
        initials   => 'Lt.'

    }
);
$pub->add_author(
    {   first_name => 'Ron',
        last_name  => 'Weasly',
        initials   => 'Jr.'
    }
);

lives_ok { $pub->create } 'create another new publication record';
is( $Pub->count(
        year       => '2050',
        title      => 'whisky',
        first_name => 'Harry',
        last_name  => 'Potter'
    ),
    1,
    'got six publications from database'
);

($pub_from_db) = $Pub->search(
    year       => '2050',
    title      => 'whisky',
    last_name  => 'Potter',
    first_name => 'Harry'
);

is( $pub_from_db->journal,
    'Liquid journal',
    'got back the journal name from database'
);

#now lets update and then do a round trip
$pub_from_db->journal('Solid journal');
$pub_from_db->year(2099);
$pub_from_db->title('Deathly hollow');
$pub_from_db->issn('22394-748');
$pub_from_db->issue(56);
$pub_from_db->status('movie');

lives_ok { $pub_from_db->update } 'updated one publication record';

my $pub_after_update = $Pub->find( $pub_from_db->dbrow->pub_id );
is( $pub_after_update->journal, $pub_from_db->journal,
    'journal name matches after update' );
is( $pub_after_update->year, $pub_from_db->year,
    'journal year matches after update' );
is( $pub_after_update->title, $pub_from_db->title,
    'journal title matches after update' );
is( $pub_after_update->issn, $pub_from_db->issn,
    'journal issn matches after update' );
is( $pub_after_update->issue, $pub_from_db->issue,
    'journal issue matches after update' );

#another new record
$pub = $Pub->new(
    year      => 2059,
    title     => 'Bourbon whisky',
    abstract  => 'Whisky kill bugs!',
    status    => 'In a pub',
    cv        => $test_cv,
    journal   => 'Bottle journal',
    pubmed_id => 2000876
);
$pub->add_author(
    {   first_name => 'Bob',
        last_name  => 'Cobb',
        suffix     => 'Sr.',
        initials   => 'Cornell.'

    }
);
my @keys = qw/Growth Adhesion Mapping Reviews/;
$pub->add_keyword($_) for @keys;
lives_ok { $pub->create } 'created new record with keywords';

my $pub_with_keyw = $Pub->find_by_pubmed_id(2000876);
$pub_with_keyw->dicty_cv(
    'Modware-dicty_literature_topic-dictyBase_literature_topic');
is_deeply(
    [ $pub_with_keyw->keywords_sorted ],
    [ sort @keys ],
    'got all keywords from storage'
);

my ($pub_from_search) = $Pub->search(
    journal => 'Ophthalmic',
    title   => 'mitochondria',
    year    => '2010'
);

is($pub_from_search->total_authors, 3,  'it has three authors');

($pub_from_search) = $Pub->search(
	last_name => 'Boulton', 
	first_name => 'Michael'
);

is($pub_from_search->total_authors, 3,  'it has three authors');



