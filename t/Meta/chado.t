use Test::More qw/no_plan/;
use Test::Moose;

{

    package MyChado;
    use Modware::Chado;

    resultset 'Pub::Pub';

    chado_has 'pub_id' => ( primary => 1 );
    chado_has 'title';
    chado_has 'volume';
    chado_has 'source' => ( column => 'pubplace' );
    chado_has 'year' => ( column => 'pyear', 'lazy' => 1 );

}

my $chado = new_ok('MyChado');
has_attribute_ok( $chado, $_, "It has attribute $_" )
    for qw/pub_id title volume source year/;

my $meta = $chado->meta;
isnt( $meta->get_attribute('pub_id'), 1, 'pub_id has not applied trait' );
for my $attr (qw/title volume source year/) {
    is( $meta->get_attribute($attr)->has_applied_traits,
        1, "$attr has applied traits" );
}
for my $attr(qw/title pub_id volume source/) {
	is($meta->has_method('has_'.$attr),  1,  "$attr has predicte");
}
is( $meta->get_attribute('source')->column,
    'pubplace', 'It has column attribute in attribute metaclass' );
is( $meta->get_attribute('year')->is_lazy, 1, 'pyear has lazy property' );
