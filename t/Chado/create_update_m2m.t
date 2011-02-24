use Test::Exception;
use aliased 'Modware::DataSource::Chado';
use Modware::Build;
use Test::More qw/no_plan/;


my $build = Modware::Build->current;
Chado->connect( $build->connect_hash );

use_ok('TestExpression');


