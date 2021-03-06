use Test::More qw/no_plan/;

use_ok('Modware::Publication::Author');

my $author = Modware::Publication::Author->new;

isa_ok( $author, 'Modware::Publication::Author' );
can_ok( 'Modware::Publication::Author', $_ )
    for
    qw/first_name initials last_name suffix rank given_name is_editor is_primary/;

$author->first_name('James Brown');
$author->initials('Mr.');
is( $author->given_name,
    'Mr. James Brown',
    'It has given name with initials'
);

$author->first_name(" Philip Brown ");
is( $author->first_name, 'Philip Brown',
    'First name has no starting or trailing whitespace' );
