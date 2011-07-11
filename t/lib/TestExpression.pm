package Test::Modware::Chado::Expression;

# Other modules:
use Modware::Chado;

# Module implementation
#
resultset 'Expression::Expression';
chado_has_many 'expression_images' =>
    ( class => 'Test::Modware::Chado::ExpressionImage' );
chado_many_to_many 'images' =>
    ( through => 'Test::Modware::Chado::ExpressionImage' ,  class =>
    'Test::Modware::Chado::Expression::Image');

package Test::Modware::Chado::ExpressionImage;

use Modware::Chado;

resultset 'Expression::ExpressionImage';
chado_belongs_to 'expression' => ( class => 'Test::Chado::Expression' );
chado_belongs_to 'image' => ( class => 'Test::Chado::Expression::Image' );

package Test::Modware::Chado::Expression::Image;
use Modware::Chado;

chado_has_many 'expression_images' =>
    ( class => 'Test::Chado::Expression::Image' );
chado_many_to_many 'expressions' =>
    ( through => 'Test::Chado::Modware::ExpressionImage' ,  class =>
    'Test::Chado::Modware::Expression' } );

1;    # Magic true value required at end of module

