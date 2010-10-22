package Modware::DataModel::Validations;

use namespace::autoclean;
use Moose;
use Modware::Types qw/ValidValues/;
use MooseX::ClassAttribute;
use Moose::Exporter;

Moose::Exporter->setup_import_methods(
    with_meta => [qw/validate_presence_of/] );

class_has 'attr_name' => (
    is      => 'rw',
    isa     => 'Str',
    default => '_attr_to_validate'
);

sub validate_presence_of {
    my ( $meta, $value ) = @_;
    my $attr_name = __PACKAGE__->attr_name;
    if ( $meta->has_attribute($attr_name) ) {
        my $attr        = $meta->find_attribute_by_name($attr_name);
        my $exist_value = $attr->get_value( $meta->name->new );
        push @$exist_value, $value;
        $attr->set_value( $meta->name->new, $exist_value );
        return;
    }
    $meta->add_attribute(
        $attr_name,
        (   is         => 'rw',
            isa        => ValidValues,
            default    => sub { return $value },
            auto_deref => 1,
            coerce     => 1
        )
    );
}

1;

