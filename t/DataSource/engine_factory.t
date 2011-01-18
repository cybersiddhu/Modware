use strict;
use warnings;

use Test::More qw/no_plan/;    # last test to print
use Test::Exception;
use aliased 'Modware::DataSource::Chado';
use Modware::Build;

BEGIN { use_ok('Modware::Factory::Chado::BCS'); }

my $build = Modware::Build->current;
Chado->connect( $build->connect_hash );

dies_ok { Modware::Factory::Chado::BCS->new( engine => 'bomb' ) }
'It throws with non existing engine';

my $generic = Modware::Factory::Chado::BCS->new();
isa_ok( $generic, 'Modware::DataSource::Chado::BCS::Engine::Generic' );
dies_ok { $generic->transform } 'It cannot transform without schema object';
is( $generic->transform( Chado->handler ),
    1, 'It transforms with a schema object' );

my $oracle = Modware::Factory::Chado::BCS->new(
    engine => 'oracle',
    schema => Chado->handler
);

isa_ok( $oracle, 'Modware::DataSource::Chado::BCS::Engine::Oracle' );
is( $oracle->transform( Chado->handler ),
    1, 'Oracle engine transforms a schema object' );
