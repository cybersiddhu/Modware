package Test::Chado::Expression;

# Other modules:
use Modware::Chado;

# Module implementation
#
resultset 'Expression::Expression';
chado_has 'id' => (column => 'expression_id',  primary => 1);
chado_has 'checksum' => (column => 'md5checksum');
chado_has 'description';
chado_has 'name' => (column => 'uniquename');
chado_many_to_many 'images' => (through => 'Test::Chado::ExpressionImage');


package Test::Chado::ExpressionImage;

use Modware::Chado;

resultset 'Expression::ExpressionImage';
chado_has 'id' => (column => 'expression_image_id',  primary => 1);
chado_has $_ for qw/expression_id eimage_id/;
chado_belongs_to 'expression' => (class => 'Test::Chado::Expression');
chado_belongs_to 'image' => (class => 'Test::Chado::Expression::Image');


package Test::Chado::Expression::Image;
use Modware::Chado;


chado_has 'id' => (column => 'eimage_id',  primary => 1);
chado_has 'data' => (column => 'eimage_data');
chado_has 'type' => (column => 'eimage_type');
chado_has 'uri' => (column => 'eimage_uri');
chado_many_to_many 'expressions' => (through => 'Test::Chado::ExpressionImage');

1;    # Magic true value required at end of module


