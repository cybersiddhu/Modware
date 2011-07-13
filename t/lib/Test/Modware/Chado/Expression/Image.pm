package Test::Modware::Chado::Expression::Image;
use Modware::Chado;

bcs_resultset 'Expression::Eimage';
chado_map_all_attributes {
    'eimage_type' => 'type',
    'image_uri'   => 'uri',
    'eimage_data' => 'data'
};

chado_has_many 'expression_images' =>
    ( class => 'Test::Modware::Chado::Expression::Image' );
chado_many_to_many 'expressions' => (
    through => 'Test::Modware::Chado::ExpressionImage',
    class   => 'Test::Modware::Chado::Expression'
);

1;    # Magic true value required at end of module

1;
