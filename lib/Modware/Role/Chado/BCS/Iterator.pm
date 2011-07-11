package Modware::Role::Chado::BCS::Iterator;

# Other modules:

use namespace::autoclean;
use Moose::Role;
use Class::MOP;
use Carp;
use Modware::Types qw/ResultSet/;

# Module implementation
#

has collection => (
    is        => 'rw',
    isa       => ResultSet,
    predicate => 'has_collection'
);


before 'next' => sub {
    my $self = shift;
    carp "cannot iterate without any related object\n" if !$self->has_collection;
    confess "data access class name is not set\n"
        if !$self->_related_class;
};

sub next {
    my ($self) = @_;
    if ( my $next = $self->collection->next ) {
        Class::MOP::load_class( $self->_related_class );
        return $self->_related_class->new( dbrow => $next );
    }

}

1;    # Magic true value required at end of module

