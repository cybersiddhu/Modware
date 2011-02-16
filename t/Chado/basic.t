use Test::More qw/no_plan/;
use Test::Exception;
use aliased 'Modware::DataSource::Chado';
use Modware::Build;
use Data::Dump qw/pp/;

{

    package MyOrganism;
    use Modware::Chado;

    bcs_resultset 'Organism::Organism';

    chado_has 'organism_id' => ( primary => 1 );
    chado_has 'abbreviation';
    chado_has 'genus' => ( lazy => 1 );
    chado_has 'species';
    chado_has 'name' => ( column => 'common_name' );

}

my $build = Modware::Build->current;
Chado->connect( $build->connect_hash );

my $org = new_ok('MyOrganism');
$org->abbreviation('D.Pulex');
$org->genus('Daphnia');
$org->species('pulex');
$org->name('water fleas');
is($org->meta->bcs_resultset,  'Organism::Organism',  'Got the value of bcs resultset');

my $new_org;
lives_ok { $new_org = $org->create } 'It creates a new record for organism';
like($new_org->organism_id, qr/\d+/,  'It has the new organism id from database');
isnt($new_org->has_genus,  1,  'genus attribute is empty now');
is($new_org->genus, 'Daphnia',  'genus attribute is lazily loaded');
is($new_org->species, 'pulex',  'got the species value from database');
