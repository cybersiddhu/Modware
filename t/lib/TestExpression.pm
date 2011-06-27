package Test::Modware::Chado::Expression;

# Other modules:
use Modware::Chado;

# Module implementation
#
resultset 'Expression::Expression';
chado_has 'id' => ( column => 'expression_id', primary => 1 );
chado_has 'checksum' => ( column => 'md5checksum' );
chado_has 'description';
chado_has 'name' => ( column => 'uniquename' );
chado_has_many 'expression_images' =>
    ( class => 'Test::Modware::Chado::ExpressionImage' );
chado_many_to_many 'images' =>
    ( through => 'Test::Modware::Chado::ExpressionImage' ,  class =>
    'Test::Modware::Chado::Expression::Image');

package Test::Modware::Chado::ExpressionImage;

use Modware::Chado;

resultset 'Expression::ExpressionImage';
chado_has 'id' => ( column => 'expression_image_id', primary => 1 );
chado_has $_ for qw/expression_id eimage_id/;
chado_belongs_to 'expression' => ( class => 'Test::Chado::Expression' );
chado_belongs_to 'image' => ( class => 'Test::Chado::Expression::Image' );

package Test::Modware::Chado::Expression::Image;
use Modware::Chado;

chado_has 'id' => ( column => 'eimage_id', primary => 1 );
chado_has 'data' => ( column => 'eimage_data' );
chado_has 'type' => ( column => 'eimage_type' );
chado_has 'uri'  => ( column => 'eimage_uri' );
chado_has_many 'expression_images' =>
    ( class => 'Test::Chado::Expression::Image' );
chado_many_to_many 'expressions' =>
    ( through => 'Test::Chado::Modware::ExpressionImage' ,  class =>
    'Test::Chado::Modware::Expression' } );

1;    # Magic true value required at end of module

