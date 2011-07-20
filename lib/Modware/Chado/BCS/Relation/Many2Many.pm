package Modware::Chado::BCS::Relation::Many2Many;

# Other modules:

use namespace::autoclean;
use Moose;
use MooseX::Params::Validate;
use Carp;

# Module implementation
#

has '_link_class' => (
    is  => 'rw',
    isa => 'Str'
);

sub add_new {
    my ( $self, %arg ) = @_;
    croak "need arguments to add new ", $self->_related_class, "\n"
        if scalar keys %arg == 0;

    my $asc_class  = $self->_related_class;
    my $link_class = $self->_link_class;
    Class::MOP::load_class($asc_class);
    Class::MOP::load_class($link_class);

    my $link_obj = $link_class->new();
    my $asc_obj = $asc_class->new(%arg);
    $link_obj->_add_belongs_to( $asc_obj->meta->pk_column,
        $asc_obj );
    $self->_parent_class->_add_has_many($link_obj);
    return $asc_obj;
}

sub create {
    my ( $self, %arg ) = @_;
    croak "need arguments to add new ", $self->_related_class, "\n"
        if scalar keys %arg == 0;

	## -- create both related and link objects and link them with foreign keys
    my $parent     = $self->_parent_class;
    my $asc_class = $self->_related_class;
    my $link_class = $self->_link_class;
    Class::MOP::load_class($asc_class);
    Class::MOP::load_class($link_class);

    my $asc_obj = $asc_class->new(%arg);
    $asc_obj->save; 

    my $bt_column = $asc_obj->meta->pk_column;
    my $pk_column     = $parent->meta->pk_column;
    my $link_obj = $link_class->new;
    $link_obj->dbrow->$pk_column($parent->dbrow->$pk_column);
    $link_obj->dbrow->$bt_column($asc_obj->dbrow->$bt_column);
    $link_obj->save;
    return $asc_obj;
}

sub delete {
    my $self = shift;
    my ($obj)
        = pos_validated_list( \@_,
        { isa => $self->_related_class, optional => 1 } );

	my $pk_column;
    if ($obj) {
    	$pk_column = $obj->meta->pk_column;
    	my $link_class = $self->_link_class;
    	Class::MOP::load_class($link_class);
        $obj->delete;
        return 1;
    }
    while ( my $obj = $self->next ) {
        $obj->delete;
    }
    return 1;
}

with 'Modware::Role::Chado::BCS::Iterator';
with 'Modware::Role::Chado::BCS::Relation';

__PACKAGE__->meta->make_immutable;

1;    # Magic true value required at end of module

