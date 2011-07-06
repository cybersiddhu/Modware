use Test::More qw/no_plan/;
use Test::Moose;

{

    package MyChado;
    use Modware::Chado;

    bcs_resultset 'Pub::Pub';

    chado_map_attribute 'pubplace' => 'source';
    chado_map_attribute 'pyear'    => 'year';
}

{
	package MyAnalysis;
	use Modware::Chado;

	bcs_resultset 'Companalysis::Analysis';
	chado_map_all_attributes {'sourceuri' => 'uri',  'timeexecuted' => 'timerun'};
	chado_skip_attribute 'sourceversion';
	chado_skip_all_attributes [qw/programversion algorithm/];
}

my $chado = new_ok('MyChado');
has_attribute_ok( $chado, $_, "It has attribute $_" )
    for
    qw/pub_id title volume volumetitle year source series_name issue pages miniref
    uniquename type_id is_obsolete publisher/;

my $meta = $chado->meta;
has_attribute_ok( $meta, 'bcs_resultset',
    'Metaclass has bcs_resultset attribute' );
is( $meta->bcs_resultset, 'Pub::Pub',
    'Got the value of bcs_resultset attribute' );
for my $attr (
    qw/pub_id title volume volumetitle year source series_name issue pages miniref
    uniquename type_id is_obsolete publisher/
    )
{
    is( $meta->has_method( 'has_' . $attr ), 1, "$attr has predicate" );
    is( $meta->get_attribute($attr)->has_trigger, 1, "$attr has trigger" );
    is( $meta->get_attribute($attr)->is_lazy, 1, "$attr is always lazy" );
}

isnt($meta->get_attribute('pub_id')->has_write_method,  1,  "it should be read only");

my $analysis = new_ok('MyAnalysis');
has_attribute_ok($analysis,  $_,  "It has $_ attribute") for qw/analysis_id name
description program sourcename/;
has_attribute_ok($analysis,  $_,  "It has mapped $_ attribute") for qw/uri timerun/;
isnt($analysis->meta->has_attribute($_),  1,  "It has skipped atttribute $_") for
qw/programversion algorithm sourceversion/;

