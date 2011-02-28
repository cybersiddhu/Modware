package Modware::Chado::BCS::Relation;

# Other modules:

use namespace::autoclean;
use Moose;
use MooseX::Params::Validate;
use Carp;

# Module implementation
#

has collection => (
    is        => 'rw',
    isa       => 'DBIx::Class::Resultset',
    predicate => 'has_collection'
);

has '_data_access_class' => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_data_access_class'
);

has '_parent_class' => (
    is   => 'rw',
    does => 'Modware::Role::Adapter::BCS::Chado'
);

sub size {
    my ($self) = @_;
    return $self->has_collection ? $self->collection->count : 0;
}

sub empty {
	my ($self) = @_;
    return $self->has_collection ? 0 : 1;
}

before [qw/add_new create/] => sub {
    my ($self) = @_;
    croak "parent object is not saved yet: cannot work with related object\n"
        if !$self->has_collection;
};

sub add_new {
    my ( $self, %arg ) = @_;
    croak "need arguments to add new ", $self->_data_access_class, "\n"
        if scalar keys %arg == 0;
    my $data_class = $self->_data_access_class;
    Class::MOP::load_class($data_class);
    my $data_obj = $data_class->new(%arg);
    $self->_parent_class->_add_has_many($data_obj);
    return $data_obj;
}

sub create {
    my ( $self, %arg ) = @_;
    croak "need arguments to add new ", $self->_data_access_class, "\n"
        if scalar keys %arg == 0;

    my $pk_col     = $self->meta->pk_column;
    my $data_class = $self->_data_access_class;
    Class::MOP::load_class($data_class);
    my $data_obj = $data_class->new(%arg);
    $data_obj->_add_to_mapper( $pk_col, $self->dbrow->$pk_col );
    $data_obj->save;
    return $data_obj;
}

with 'Modware::Role::Chado::BCS::Iterator';

1;    # Magic true value required at end of module

