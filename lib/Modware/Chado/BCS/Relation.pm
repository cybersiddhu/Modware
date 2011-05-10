package Modware::Chado::BCS::Relation;

# Other modules:

use namespace::autoclean;
use Moose;
use MooseX::Params::Validate;
use Carp;
use Modware::Types qw/ResultSet/;

# Module implementation
#

has collection => (
    is        => 'rw',
    isa       => ResultSet,
    predicate => 'has_collection'
);

has '_data_access_class' => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_data_access_class'
);

has '_parent_class' => (
    is        => 'rw',
    does      => 'Modware::Role::Adapter::BCS::Chado',
    predicate => 'has_parent_class'
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

	my $parent = $self->_parent_class;
    my $pk_col     = $parent->meta->pk_column;
    my $data_class = $self->_data_access_class;
    Class::MOP::load_class($data_class);
    my $data_obj = $data_class->new(%arg);
    $data_obj->_add_to_mapper( $pk_col, $parent->dbrow->$pk_col );
    return $data_obj->save;
}

sub delete {
    my $self = shift;
    my ($obj)
        = pos_validated_list( \@_,
        { isa => $self->_data_access_class, optional => 1 } );

	if ($obj) {
		$obj->delete;
		return 1;
	}
	while(my $obj = $self->next) {
		$obj->delete;
	}
	return 1;
}

with 'Modware::Role::Chado::BCS::Iterator';

1;    # Magic true value required at end of module
