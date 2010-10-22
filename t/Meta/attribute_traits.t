use Test::More qw/no_plan/;
use Test::Moose;

{

    package MyPersist;
    use Moose;
    use Modware::Meta;

    has 'id' => (
        isa    => 'Str',
        is     => 'rw',
        traits => [qw/Persistent/]
    );

    has 'type' => (
        isa    => 'Str',
        isa    => 'rw',
        traits => [qw/Persistent::Cvterm/]
    );

    has 'accession' => (
        isa    => 'Int',
        isa    => 'rw',
        traits => [qw/Persistent::PubDbxref/]
    );

    has 'uniprot' => (
        isa    => 'Int',
        isa    => 'rw',
        traits => [qw/Persistent::PubProp/]
    );

    has 'author' => (
        is     => 'rw',
        isa    => 'ArrayRef',
        traits => [qw/Persistent::PubAuthors/]
    );
}

my $persist = MyPersist->new;
my $meta    = $persist->meta;

does_ok( $persist, $_, "It does $_ traits" )
    for (
    'Persistent',             'Persistent::PubProp',
    'Persistent::PubAuthors', 'Persistent::Cvterm'
    );

my $id_attr = $meta->get_attribute('id');
has_attribute_ok( $id_attr, 'column',
    'Persistent trait has column attribute' );

my $type_attr = $meta->get_attribute('type');
has_attribute_ok( $id_attr, $_, "Cvterm trait has $_ attribute" )
    for qw/cv db/;

my $acc_attr = $meta->get_attribute('accession');
has_attribute_ok( $acc_attr, 'db', 'Dbxref trait has column attribute' );

my $uniprot_attr = $meta->get_attribute('uniprot');
has_attribute_ok( $uniprot_attr, $_, "Pubprop trait has $_ attribute" )
    for qw/cv db rank cvterm/;

my $author_attr = $meta->get_attribute('author');
has_attribute_ok( $author_attr, $_, "Author trait has $_ attribute" )
    for qw/map_to association/;
