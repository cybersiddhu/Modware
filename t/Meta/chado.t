use Test::More qw/no_plan/;
use Test::Moose;

{

    package MyChado;
    use Modware::Chado;

    bcs_resultset 'Pub::Pub';

    chado_has 'pub_id' => ( primary => 1 );
    chado_has 'title';
    chado_has 'volume'      => ( 'lazy_fetch' => 1 );
    chado_has 'source'      => ( column       => 'pubplace' );
    chado_has 'year'        => ( column       => 'pyear', 'lazy_fetch' => 1 );
    chado_property 'status' => ( cvterm       => 'pub_status' );
    chado_property 'journal' => ( cvterm => 'journal_type', lazy => 1 );
    chado_dbxref 'medline_id' => (db => 'Phantom');
    chado_type 'pub_type';

}

my $chado = new_ok('MyChado');
has_attribute_ok( $chado, $_, "It has attribute $_" )
    for qw/pub_id title volume source year status journal pub_type medline_id/;

my $meta = $chado->meta;
has_attribute_ok( $meta, 'bcs_resultset',
    'Metaclass has bcs_resultset attribute' );
is( $meta->bcs_resultset, 'Pub::Pub',
    'Got the value of bcs_resultset attribute' );
for my $attr (qw/pub_id title volume source year journal status pub_type/) {
    is( $meta->get_attribute($attr)->has_applied_traits,
        1, "$attr has applied traits" );
}
for my $attr (qw/title pub_id volume source status year journal pub_type/) {
    is( $meta->has_method( 'has_' . $attr ), 1, "$attr has predicate" );
}
is( $meta->get_attribute('source')->column,
    'pubplace', 'source has column attribute in attribute metaclass' );
is( $meta->get_attribute('volume')->lazy_fetch,
    1,, 'volume attribute has lazy_fetch attribute in attribute metaclass' );
is( $meta->get_attribute('medline_id')->has_trigger,
    1,, 'medline_id attribute has trigger parameter defined' );
is( $meta->get_attribute($_)->is_lazy, 1, "$_ is always lazy attribute" )
    for qw/medline_id pub_id title volume source year/;

is( $meta->get_attribute($_)->bcs_accessor,
    'pubprops', "$_ has bcs_accessor added in the metaclass" )
    for qw/status journal/;


