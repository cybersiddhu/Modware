package Modware::DataModel::Validation;

use namespace::autoclean;
use Moose;
use MooseX::ClassAttribute;
use Moose::Exporter;

Moose::Exporter->setup_import_methods( as_is => [qw/validate_presence_of/] );

class_has 'validation_stack' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    traits  => [qw/Array/],
    default => sub { [] },
    handles => {
        add_for_validation => 'push',
        attributes         => 'elements'
    }
);

sub validate_presence_of {
    __PACKAGE__->add_for_validation($_) for @_;
}

1;

