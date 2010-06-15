use Test::More qw/no_plan/;

use_ok('ModwareX::Publication::Author');

my $author = ModwareX::Publication::Author->new;

isa_ok( $author, 'ModwareX::Publication::Author' );
can_ok( 'ModwareX::Publication::Author', $_ )
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
