package Test::Modware::Chado::Expression;

# Other modules:
use Modware::Chado;

# Module implementation
#
bcs_resultset 'Expression::Expression';
chado_has_many 'expression_images' =>
    ( class => 'Test::Modware::Chado::ExpressionImage' );
chado_many_to_many 'images' =>
    ( through => 'Test::Modware::Chado::ExpressionImage' ,  class =>
    'Test::Modware::Chado::Expression::Image');

1;
