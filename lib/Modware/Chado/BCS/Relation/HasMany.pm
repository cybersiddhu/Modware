package Modware::Chado::BCS::Relation::HasMany;

# Other modules:

use namespace::autoclean;
use Moose;
use MooseX::Params::Validate;
use Carp;

# Module implementation
#

sub add_new {
    my ( $self, %arg ) = @_;
    croak "need arguments to add new ", $self->_related_class, "\n"
        if scalar keys %arg == 0;
    my $asc_class = $self->_related_class;
    Class::MOP::load_class($asc_class);
    my $obj = $asc_class->new(%arg);
    $self->_parent_class->_add_has_many($obj);
    return $obj;
}

sub create {
    my ( $self, %arg ) = @_;
    croak "need arguments to add new ", $self->_related_class, "\n"
        if scalar keys %arg == 0;

	my $parent = $self->_parent_class;
    my $pk_col     = $parent->meta->pk_column;
    my $asc_class = $self->_related_class;
    Class::MOP::load_class($asc_class);
    my $obj = $asc_class->new(%arg);
    $obj->dbrow->$pk_col(($parent->dbrow->id)[0] );
    return $obj->save;
}

sub delete {
    my $self = shift;
    my ($obj)
        = pos_validated_list( \@_,
        { isa => $self->_associated_class, optional => 1 } );

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
with 'Modware::Role::Chado::BCS::Relation';

1;    # Magic true value required at end of module

