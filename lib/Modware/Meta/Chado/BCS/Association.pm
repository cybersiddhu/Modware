package Modware::Meta::Chado::BCS::Association;

use strict;

# Other modules:
use namespace::autoclean;
use MooseX::Params::Validate;
use Moose::Role;
use Class::MOP::Method;
use List::Util qw/first/;
use Scalar::Util qw/blessed/;
use Carp;
use Class::MOP;

# Module implementation
#

sub add_belongs_to {
    my ( $meta, $name, %options ) = @_;
    my $related_class;
    my $bcs_accs;
    my $bcs_source = $meta->bcs_source;

    $related_class = $options{class} if defined $options{class};
    if ( !$related_class ) {
        $related_class = $meta->base_namespace . '::' . ucfirst( lc $name );
    }
    Class::MOP::load_class($related_class);
    my $related_source = $related_class->new->meta->bcs_source->source_name;

    $bcs_accs = $options{bcs_accessor} if defined $options{bcs_accessor};
    if ( !$bcs_accs ) {
        $bcs_accs = first {
            $related_source eq $bcs_source->related_source($_)->source_name;
        }
        $bcs_source->relationships;
    }

    my $rel_info = $bcs_source->relationship_info($bcs_accs);
    my ($fk_column) = keys %{ $rel_info->{attrs}->{fk_columns} };

    #association(object[optional])
    my $code = sub {
        my $self = shift;
        my ($obj)
            = pos_validated_list( \@_,
            { isa => $related_class, optional => 1 } );

        if ( defined $obj ) {    # -- set call
            if ( $obj->new_record ) {
                $self->_add_belongs_to( $fk_column, $obj );
            }
            else {
                $self->_add_to_mapper( $fk_column, $obj->dbrow->$fk_column );
            }
            return 1;
        }
        else {
            if ( !$self->new_record ) {
                my $dbrow = $self->dbrow;
                if ( defined $dbrow->$fk_column ) {
                    return $related_class->new( dbrow => $dbrow->$bcs_accs );
                }
            }
        }
    };

    #create_association(params)
    my $code2 = sub {
        my ( $self, %arg ) = @_;
        croak "need arguments to create $related_class\n"
            if scalar keys %arg == 0;
        my $obj = $related_class->new(%arg)->save;
        $self->_add_to_mapper( $fk_column, $obj->dbrow->$fk_column );
        return $obj;
    };

    #new_association(params)
    my $code3 = sub {
        my ( $self, %arg ) = @_;
        croak "need arguments to create $related_class\n"
            if scalar keys %arg == 0;
        my $obj = $related_class->new(%arg);
        $self->_add_belongs_to( $fk_column, $obj );
        return $obj;
    };

    $meta->add_method(
        $name,
        Class::MOP::Method->wrap(
            $code,
            name         => $name,
            package_name => $meta->name
        )
    );

    $meta->add_method(
        'create_' . $name,
        Class::MOP::Method->wrap(
            $code2,
            name         => 'create_' . $name,
            package_name => $meta->name
        )
    );

    $meta->add_method(
        'new_' . $name,
        Class::MOP::Method->wrap(
            $code3,
            name         => 'new_' . $name,
            package_name => $meta->name
        )
    );

}

sub add_has_many {
    my ( $meta, $name, %options ) = @_;
    my $class_name;
    my $accessor;

    if ( defined $options{class_name} ) {
        $class_name = $options{class_name};
    }
    else {
        $class_name = $meta->name . '::' . ucfirst( to_S($name) );
    }

    if ( defined $options{accessor} ) {
        $accessor = $options{accessor};
    }
    else {
        Class::MOP::load_class($class_name);
        my $assoc_bcs
            = $meta->bcs->source( $class_name->new->meta->resultset )
            ->source_name;
        my $bcs_source = $meta->bcs->source( $meta->resultset );
        $accessor = first {
            $assoc_bcs eq $bcs_source->related_source($_)->source_name;
        }
        $bcs_source->relationships;

        if ( !$accessor ) {
            warn "unable to find Bio::Chado::Schema relationship accessor\n";
            carp
                "please check your resultset name or provide a valid Bio::Chado::Schema accessor name\n";
        }
    }

    my $code = sub {
        my ($self) = @_;
        if ( wantarray() ) {
            my @arr;
            push @arr, $accessor . ' ' . $class_name for 0 .. 10;
            return @arr;
        }
        return $accessor . ' ' . $class_name;
    };
    $meta->add_method(
        $name,
        Class::MOP::Method->wrap(
            $code,
            name         => $name,
            package_name => $meta->name
        )
    );
}

1;    # Magic true value required at end of module

