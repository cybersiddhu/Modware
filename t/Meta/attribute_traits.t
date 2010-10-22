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
        is     => 'rw',
        traits => [qw/Persistent::Cvterm/]
    );

    has 'accession' => (
        isa    => 'Int',
        is     => 'rw',
        traits => [qw/Persistent::Pubdbxref/]
    );

    has 'uniprot' => (
        isa    => 'Int',
        is     => 'rw',
        traits => [qw/Persistent::Pubprop/]
    );

    has 'author' => (
        is     => 'rw',
        isa    => 'ArrayRef',
        traits => [qw/Persistent::Pubauthors/]
    );
}

my $persist = MyPersist->new;
my $meta    = $persist->meta;

my $id_attr = $meta->get_attribute('id');
does_ok(
    $id_attr, 'Modware::Meta::Attribute::Trait::Persistent',
    'It does Persistent trait'
);
has_attribute_ok( $id_attr, 'column',
    'Persistent trait has column attribute' );

my $type_attr = $meta->get_attribute('type');
does_ok(
    $type_attr, 'Modware::Meta::Attribute::Trait::Persistent::Cvterm',
    'It does Cvterm trait'
);
has_attribute_ok( $type_attr, $_, "Cvterm trait has $_ attribute" )
    for qw/cv db/;

my $acc_attr = $meta->get_attribute('accession');
has_attribute_ok( $acc_attr, 'db', 'Dbxref trait has column attribute' );

my $uniprot_attr = $meta->get_attribute('uniprot');
has_attribute_ok( $uniprot_attr, $_, "Pubprop trait has $_ attribute" )
    for qw/cv db rank cvterm/;

my $author_attr = $meta->get_attribute('author');
has_attribute_ok( $author_attr, $_, "Author trait has $_ attribute" )
    for qw/map_to association/;
