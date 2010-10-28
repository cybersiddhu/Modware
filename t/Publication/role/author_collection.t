use Test::More qw/no_plan/;
use Test::Exception;
use Modware::Publication::Author;

{

    package MyAuthors;
    use Moose;
    use Modware::Publication::Author;
    with 'Modware::Role::Publication::HasAuthors';

}

my $author1 = Modware::Publication::Author->new(
    first_name => 'Harry',
    last_name  => 'Jones',
    suffix     => 'Jr.'
);

my $author2 = Modware::Publication::Author->new(
    first_name => 'Harry',
    last_name  => 'Jones',
    suffix     => 'Sr.'
);

my $author3 = Modware::Publication::Author->new(
    first_name => 'Pierce',
    last_name  => 'Marshall',
    initials   => 'Mr.'
);

my $collection = MyAuthors->new;

$collection->add_author($_) for ( $author1, $author2, $author3 );
is( $collection->total_authors, 3, 'has 3 authors' );
my @authors = $collection->authors;
is( $authors[$_]->rank, $_ + 1,
    "author has rank decided by the order of addition" )
    for 0 .. 2;

#now change the rank and see if they come out accordingly
$author3->rank(1);
$author1->rank(2);
$author2->rank(3);

$collection->delete_authors;
$collection->add_author($_) for ( $author1, $author2, $author3 );

@authors = $collection->authors;
is( $authors[0]->first_name,
    $author3->first_name, 'has author with highest rank' );

#add author directly with attributes
$collection->add_author(
    {   first_name => 'Thomas',
        last_name  => 'Hanks',
        initials   => 'Mr.'
    }
);
@authors = $collection->authors;
is( $authors[-1]->last_name,
    'Hanks', 'has author added with direct attributes' );

while ( my $obj = $collection->next_author ) {
    isa_ok( $obj, 'Modware::Publication::Author' );
}

my $author4 = Modware::Publication::Author->new(
    first_name => 'Pierce',
    last_name  => 'Johnson',
    initials   => 'Mr.',
    rank       => 2
);

throws_ok { $collection->add_author($author4) } qr/authors collection/,
    'throws with authors having identical rank';

