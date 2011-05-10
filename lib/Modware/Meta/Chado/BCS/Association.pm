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
    $meta->_add_method2class( $name, $related_class );
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

    #association(object[optional]) -- dense logic alarm
    my $code = sub {
        my $self = shift;
        my ($obj)
            = pos_validated_list( \@_,
            { isa => $related_class, optional => 1 } );

        # -- set call
        if ( defined $obj ) {
            ## -- here the parent object assumes the related object do not exist in the
            ## -- database level. If a new instance of existing related object gets added
            ## -- again,  the parent object's create/update method will be blocked at the
            ## -- database level(existing foreign key error).
            if ( $obj->new_record ) {    ## -- new related record
                ## -- new parent object: related object will be saved by insert
                ## -- existing parent object: related object will be saved by update
                $self->_add_belongs_to( $fk_column, $obj );
            }
            else {                       ## -- existing related record
                ## -- parent object is new: it add a foreign key
                ## -- parent object exist: it assumes the related object might have some
                ## -- updates and the update method of related object gets called during the
                ## -- parent's update method.
                $self->new_record
                    ? $self->_add_to_mapper( $fk_column,
                    $obj->dbrow->$fk_column )
                    : $self->_add_belongs_to( $fk_column, $obj );
            }
            return 1;
        }
        else
        { ## -- it's a get call and a related object is return only from a persistent
            ## -- parent object
            if ( !$self->new_record ) {
                my $dbrow = $self->dbrow;
                if ( defined $dbrow->$fk_column ) {
                    return $related_class->new(
                        dbrow => $dbrow->$bcs_accs->get_from_storage );
                }
            }
        }
    };

    #create_association(params)
    my $code2 = sub {
        my ( $self, %arg ) = @_;
        croak "need arguments to create $related_class\n"
            if scalar keys %arg == 0;
        croak ref($self), " needs to be saved before creating association\n"
            if $self->new_record;
        my $obj = $related_class->new(%arg)->save;
        $self->_add_to_mapper( $fk_column, $obj->dbrow->$fk_column );
        return $obj;
    };

    #new_association(params)
    my $code3 = sub {
        my ( $self, %arg ) = @_;
        croak "need arguments to create $related_class\n"
            if scalar keys %arg == 0;
        croak ref($self), " needs to be saved before creating association\n"
            if $self->new_record;
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
    my $related_class;
    my $bcs_accs;
    my $bcs_source = $meta->bcs_source;

    $related_class = $options{class} if defined $options{class};
    if ( !$related_class ) {
        $related_class = $meta->base_namespace . '::' . ucfirst( lc $name );
    }
    $meta->_add_method2class( $name, $related_class );

    Class::MOP::load_class($related_class);
    my $related_source = $related_class->new->meta->bcs_source->source_name;

    $bcs_accs = $options{bcs_accessor} if defined $options{bcs_accessor};
    if ( !$bcs_accs ) {
        $bcs_accs = first {
            $related_source eq $bcs_source->related_source($_)->source_name;
        }
        $bcs_source->relationships;
    }
    my $pk_column = $meta->pk_column;

    #association(object[optional]) -- dense logic alarm
    my $code = sub {
        my $self = shift;
        my ($obj)
            = pos_validated_list( \@_,
            { isa => $related_class, optional => 1 } );

        # -- set call
        if ( defined $obj ) {
            ## -- here the parent object assumes the related object do not exist in the
            ## -- database level. If a new instance of existing related object gets added
            ## -- again,  the parent object's create/update method will be blocked at the
            ## -- database level(existing foreign key error).

            if ( $obj->new_record ) {    ## -- new related record
                if ( $self->new_record )
                {    ## --related will be saved with parent
                    $self->_add_has_many($obj);
                }
                else {    ## -- related is saved with foreign key from parent
                    $obj->_add_to_mapper( $pk_column,
                        $self->dbrow->$pk_column );
                    $obj->save;
                }
            }
            else {        ## -- existing related record
                ## --- after the parent is saved related is updated with the foreign key
                if ( $self->new_record ) {
                    $self->_add_exist_has_many($obj);
                }
                else {
                    ## --- related is updated with foreign key from parent
                    $obj->_add_to_mapper( $pk_column,
                        $self->dbrow->$pk_column );
                    $obj->save;
                }
            }
            return 1;
        }
        else
        { ## -- it's a get call and a related object is return only from an existing
            ## -- parent
            Class::MOP::load_class('Modware::Chado::BCS::Relation');
            my $rel_obj;
            ## -- parent object
            if ( $self->new_record ) {
                $rel_obj = Modware::Chado::BCS::Relation->new;
            }
            else {
                my $dbrow = $self->dbrow;
                if ( wantarray() ) {
                    return
                        map { $related_class->new( dbrow => $_ ) }
                        $dbrow->$bcs_accs;
                }
                my $method = $bcs_accs . '_rs';
                $rel_obj = Modware::Chado::BCS::Relation->new(
                    collection           => $dbrow->$method,
                    '_data_access_class' => $related_class,
                    '_parent_class'      => $self
                );
            }
            return $rel_obj;
        }
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

sub add_many_to_many {
    my ( $meta, $name, %options ) = @_;

	## -- the logic below is to set up
	# - has_many and belongs_to methods
	# - model classes through has_many and belongs_to relations
	# - primary keys for model class(link class through has_many relations)  
	# - bcs accessors for has_many and belongs_to relations

    my ($has_many_method) = keys %{ $options{through} };
    croak
        "$has_many_method is not mapped to any class:  many_to_many method cannot be installed\n"
        if !$meta->_has_method2class($has_many_method);

    my $hm_class = $meta->_method2class($has_many_method);
    Class::MOP::load_class($hm_class);
    my $bt_method = $options{through}->{$has_many_method};
    croak "$link_class do not have any method $bt_method defined\n"
        croak
        "$bt_method is not mapped to any class:  many_to_many method cannot be installed\n"
        if !$link_class->meta->_has_method2class($bt_method);

    $bt_class = $link_class->meta->_method2class($bt_method);
    Class::MOP::load_class($bt_class);

    my $pk_column    = $meta->pk_column;
    my $bt_pk_column = $bt_class->meta->pk_column;

    my $code = sub {
        my $self = shift;
        my ($obj)
            = pos_validated_list( \@_,
            { isa => $bt_class, optional => 1 } );

        # -- set call
        if ( defined $obj ) {
            if ( $obj->new_record ) {    ## -- new related record
                if ( $self->new_record )
                {    ## --related will be saved with parent
                    $self->_add_many_to_many($obj);
                }
                else {    ## -- related is saved with foreign key from parent
                    my $new_obj = $hm_class->new;
                    $new_obj->_add_to_mapper( $pk_column,
                        $self->dbrow->$pk_column );
                    $new_obj->add_to_mapper( $bt_pk_column,
                        $obj->save->dbrow->$bt_pk_column );
                    $new_obj->save;
                }
            }
            else {        ## -- existing related record
                ## --- after the parent is saved related is updated with the foreign key
                if ( $self->new_record ) {
                    $self->_add_exist_many_to_many($obj);
                }
                else {
                    ## --- related is linked
					my $new_obj = $hm_class->new;
                    $new_obj->_add_to_mapper( $pk_column,
                        $self->dbrow->$pk_column );
                    $new_obj->add_to_mapper( $bt_pk_column,
                        $obj->dbrow->$bt_pk_column );
                    $new_obj->save;
                }
            }
            return 1;
        }
        else
        { 
            Class::MOP::load_class('Modware::Chado::BCS::Relation');
            my $rel_obj;
            if ( $self->new_record ) { ## -- empty relation
                $rel_obj = Modware::Chado::BCS::Relation->new;
            }
            else { # -- list or iterator based on context
                if ( wantarray() ) {
                    return
                        map { $_->$bt_method }
                        $self->$has_many_method;
                }
                my $method = $bcs_accs . '_rs';
                $rel_obj = Modware::Chado::BCS::Relation->new(
                    collection           => $dbrow->$method,
                    '_data_access_class' => $related_class,
                    '_parent_class'      => $self
                );
            }
            return $rel_obj;
        }
    };

}

1;    # Magic true value required at end of module
