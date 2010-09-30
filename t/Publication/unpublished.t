use strict;
use Test::More qw/no_plan/;
use Test::Exception;
use aliased 'Modware::DataSource::Chado';
use Modware::Build;
use aliased 'Modware::Publication::Author';

BEGIN {
    use_ok('Modware::Publication::Unpublished');
}

my $build = Modware::Build->current;
Chado->connect(
    dsn      => $build->config_data('dsn'),
    user     => $build->config_data('user'),
    password => $build->config_data('password')
);


my $test_cv = 'Modware-publication-pub_type';
my $Pub     = 'Modware::Publication::Unpublished';

my $pub = $Pub->new( year => 2090 );
$pub->title('The unpublished title for publication');
$pub->abstract('The abstract that remain unpublished');
$pub->status('unpublished');
$pub->cv($test_cv);
dies_ok { $pub->create } 'It cannot create record without author';
$pub->add_author(
    Author->new(
        first_name => 'Real man',
        last_name  => 'Unknown name',
        initials   => 'Mr.'
    )
);
$pub->add_author(
    Author->new(
        first_name => 'Larry',
        last_name  => 'Matter',
        initials   => 'Mr.'
    )
);

lives_ok { $pub->create } 'It needs author to create a record';

#lets find the record with our cool search API
is( $Pub->count(
        title => 'unpublished',
        year  => 2090,
    ),
    1,
    'has got the created unpublished record from database'
);


my ($pub_from_db) = $Pub->search( author => 'Larry' );
is( $pub_from_db->title, $pub->title, 'retrieved record matches in title' );
is( $pub_from_db->year, $pub->year, 'retrieved record matches in year' );
is( $pub_from_db->status, $pub->status,
    'retrieved record matches in status' );
is( $pub_from_db->total_authors, 2, 'retrieved record has two authors' );

my $author = $pub_from_db->get_from_authors(0);
isa_ok( $author, 'Modware::Publication::Author' );

lives_ok { $pub_from_db->delete( { cascade => 1 } ) } 'The record is deleted';
is( $Pub->count(
        title => 'unpublished',
        year  => 2090,
    ),
    0,
    'got no record from database after deletion'
);

