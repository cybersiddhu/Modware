
package Test::Modware::Chado::ExpressionImage;

use Modware::Chado;

bcs_resultset 'Expression::ExpressionImage';
chado_belongs_to 'expression' => ( class => 'Test::Modware::Chado::Expression' );
chado_belongs_to 'image' => ( class => 'Test::Modware::Chado::Expression::Image' );
1;
