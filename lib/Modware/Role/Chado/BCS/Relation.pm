package Modware::Role::Chado::BCS::Relation;

# Other modules:

use namespace::autoclean;
use Moose::Role;
use MooseX::Params::Validate;
use Carp;

# Module implementation
#
requires 'collection';
requires 'next';
requires 'create';
requires 'delete';
requires 'add_new';

has '_related_class' => (
    is        => 'rw',
    isa       => 'Str',
    predicate => '_has_associated_class'
);

has '_parent_class' => (
    is        => 'rw',
    does      => 'Modware::Role::Adapter::BCS::Chado',
    predicate => '_has_parent_class'
);

sub size {
    my ($self) = @_;
    return $self->has_collection ? $self->collection->count : 0;
}

sub empty {
    my ($self) = @_;
    return $self->has_collection ? 0 : 1;
}

before [qw/add_new create delete/] => sub {
    my ($self) = @_;
    croak "parent object is not saved yet: cannot work with related object\n"
        if !$self->has_collection;
};

1;    # Magic true value required at end of module

