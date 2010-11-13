package Modware::Role::Adapter::BCS::Chado;

# Other modules:
use namespace::autoclean;
use Moose::Role;
use Try::Tiny;
use Moose::Util qw/ensure_all_roles/;
use Lingua::EN::Inflect::Phrase qw/to_S/;
use Modware::DataSource::Chado;
use aliased 'Modware::DataModel::Validation';
use Data::Dumper::Concise;
use Carp;

# Module implementation
#
with 'Modware::Role::Chado::Helper::BCS::Cvterm';
with 'Modware::Role::Chado::Helper::BCS::Dbxref';

has 'datasource' => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_datasource'
);

has 'chado' => (
    is         => 'rw',
    isa        => 'Bio::Chado::Schema',
    lazy_build => 1
);

has 'dbrow' => (
    is        => 'rw',
    isa       => 'DBIx::Class::Row',
    predicate => 'has_dbrow',
    clearer   => '_clear_dbrow',
    trigger   => \&read
);

has 'read_hooks' => (
    is      => 'rw',
    isa     => 'HashRef[CodeRef]',
    traits  => [qw/Hash/],
    handles => {
        'all_read_hooks' => 'keys',
        'get_read_hook'  => 'get',
        'has_read_hook'  => 'defined',
        'add_read_hook'  => 'set'
    },
    default => sub {
        my $self = shift;
        return {
            'Modware::Meta::Attribute::Trait::Persistent' =>
                sub { $self->read_generic(@_) },
            'Modware::Meta::Attribute::Trait::Persistent::Cvterm' =>
                sub { $self->read_cvterm(@_) }
        };
    }
);

has 'create_hooks' => (
    is      => 'rw',
    isa     => 'HashRef[CodeRef]',
    traits  => [qw/Hash/],
    handles => {
        'all_create_hooks' => 'keys',
        'get_create_hook'  => 'get',
        'has_create_hook'  => 'defined',
        'add_create_hook'  => 'set'
    },
    default => sub {
        my $self = shift;
        return {
            'Modware::Meta::Attribute::Trait::Persistent' =>
                sub { $self->create_generic(@_) },
            'Modware::Meta::Attribute::Trait::Persistent::Cvterm' =>
                sub { $self->create_cvterm(@_) }
        };
    }
);

has 'update_hooks' => (
    is      => 'rw',
    isa     => 'HashRef[CodeRef]',
    traits  => [qw/Hash/],
    handles => {
        'all_update_hooks' => 'keys',
        'get_update_hook'  => 'get',
        'has_update_hook'  => 'defined',
        'add_update_hook'  => 'set'
    },
    default => sub {
        my $self = shift;
        return {
            'Modware::Meta::Attribute::Trait::Persistent' =>
                sub { $self->update_generic(@_) },
            'Modware::Meta::Attribute::Trait::Persistent::Cvterm' =>
                sub { $self->update_cvterm(@_) }
        };
    }
);

sub _build_chado {
    my ($self) = @_;
    my $chado
        = $self->has_datasource
        ? Modware::DataSource::Chado->handler( $self->datasource )
        : Modware::DataSource::Chado->handler;
    $chado;
}

sub do_validation {
    my ($self) = @_;
    for my $name ( Validation->attributes ) {
        if ( my $attr = $self->meta->find_attribute_by_name($name) ) {
            croak $attr->name, "\tcannot be empty\n"
                if !$attr->has_value($self);
        }
        else {
            croak "attr $name does not exist\n";
        }
    }
}

sub read {
    my ( $self, $dbrow ) = @_;
    my $meta = $self->meta;
PERSISTENT:
    for my $attr ( $meta->get_all_attributes ) {
    TRAIT:
        for my $traits ( $self->all_read_hooks ) {
            next TRAIT if !$attr->does($traits);
            my $code = $self->get_read_hook($traits);
            $code->( $attr, $dbrow );
        }
    }
}

sub read_generic {
    my ( $self, $attr, $dbrow ) = @_;
    my $column = $attr->has_column ? $attr->column : $attr->name;
    $attr->set_value( $self, $dbrow->$column );
}

sub read_cvterm {
    my ( $self, $attr, $dbrow ) = @_;
    $attr->set_value( $self, $dbrow->type->name );
}

sub create_generic {
    my ( $self, $attr ) = @_;
    my $column = $attr->has_column ? $attr->column : $attr->name;
    $self->add_to_mapper( $column, $attr->get_value($self) );
}

sub create_cvterm {
    my ( $self, $attr ) = @_;
    my $column = $attr->has_column ? $attr->column : $attr->name;
    $self->add_to_mapper(
        $column,
        $self->find_or_create_cvterm_id(
            cvterm => $attr->get_value($self),
            cv     => $attr->cv,
            db     => $attr->db
        )
    );
}

sub update_generic {
    my ( $self, $attr, $dbrow ) = @_;
    my $column = $attr->has_column ? $attr->column : $attr->name;
    $dbrow->$column( $attr->get_value($self) );
}

sub update_cvterm {
    my ( $self, $attr, $dbrow ) = @_;
    my $column = $attr->has_column ? $attr->column : $attr->name;
    $dbrow->$column(
        $self->find_or_create_cvterm_id(
            cvterm => $attr->get_value($self),
            cv     => $attr->cv,
            db     => $attr->db
        )
    );
}

sub m2m_probe {
    my ( $self, $source_name, $rel_name ) = @_;
    return if $rel_name !~ /\_/;
    my $belong_to = ( ( split /\_/, $rel_name ) )[1];
    my $singular  = to_S($belong_to);
    my $source    = $self->chado->source($source_name);
    my $m2m_rel_source
        = $source->related_source($rel_name)->related_source($singular);
    my @column = $m2m_rel_source->primary_columns;

    croak "more than one column for $rel_name\n" if @column > 1;
    return ( $singular, $column[0] );
}

sub inflate_to_hashref {
    my $self = shift;
    $self->create( fake => 1 );
    $self->insert_hashref;
}

sub create {
    my ( $self, %arg ) = @_;

    croak "cannot create a new object which already exist in the database\n"
        if $self->has_dbrow;

    ## -- check for attribute probably will go through require pragma once moose support
    ## -- validation through stack roles
    if ( !$self->meta->has_attribute('resultset_class') ) {
        croak "**resultset_class** attribute need to be defined\n";
    }

    $self->do_validation;

    my $meta = $self->meta;
    if ( !$self->does('Modware::Role::Chado::Helper::BCS::WithDataStash') ) {
        $meta->make_mutable;
        ensure_all_roles( $self,
            'Modware::Role::Chado::Helper::BCS::WithDataStash' );
        $meta->make_immutable;
    }

PERSISTENT:
    for my $attr ( $meta->get_all_attributes ) {
        next PERSISTENT if !$attr->has_value($self);
    TRAIT:
        for my $traits ( $self->all_create_hooks ) {
            next TRAIT if !$attr->does($traits);
            my $code = $self->get_create_hook($traits);
            $code->($attr);
        }
    }

    #dry run just in case you need the hashref
    return if defined $arg{fake};

    my $chado = $self->chado;
    my $dbrow = $chado->txn_do(
        sub {
            my $value = $chado->resultset( $self->resultset_class )
                ->create( $self->insert_hashref );
            $value;
        }
    );
    my $class = $self->meta->name;
    return $class->new( dbrow => $dbrow );
}

sub new_record {
	my $self = shift;
	return $self->has_dbrow ? 0 : 1;
}

sub save {
    my ($self) = @_;
    return $self->has_dbrow ? $self->update : $self->create;
}

sub update {
    my ($self) = @_;

    ## -- check for attribute probably will go through require pragma once moose support
    ## -- validation through stack roles
    if ( !$self->meta->has_attribute('resultset_class') ) {
        croak "**resultset_class** attribute need to be defined\n";
    }

    confess "No data being fetched from storage: nothing to update\n"
        if !$self->has_dbrow;

    $self->do_validation;

    if ( !$self->does('Modware::Role::Chado::Helper::BCS::WithDataStash') ) {
        $self->meta->make_mutable;
        ensure_all_roles( $self,
            'Modware::Role::Chado::Helper::BCS::WithDataStash' );
        $self->meta->make_immutable;
    }

PERSISTENT:
    for my $attr ( $self->meta->get_all_attributes ) {
        if ( !$attr->has_value($self) ) {
            next PERSISTENT;
        }
    TRAIT:
        for my $traits ( $self->all_update_hooks ) {
            if ( !$attr->does($traits) ) {
                next TRAIT;
            }
            my $code = $self->get_update_hook($traits);
            $code->( $attr, $self->dbrow );
        }
    }

    my $chado = $self->chado;
    my $dbrow = $self->dbrow;
    $chado->txn_do(
        sub {
            $dbrow->update();
            if ( $self->can('has_many_update') ) {
                for my $name ( $self->has_many_update_stash ) {
                    my $method = 'all_update_' . $name;
                    for my $hashref ( $self->$method ) {
                        $dbrow->update_or_create_related( $name, $hashref );
                    }
                }
            }

            # -- for M2M relationship
            if ( $self->can('many_to_many_update_stash') ) {
            M2M:
                for my $name ( $self->many_to_many_update_stash ) {
                    my $method = 'all_update_' . $name;
                    my ( $rel, $primary_key )
                        = $self->m2m_probe( $self->resultset_class, $name );
                HASHREF:
                    for my $hashref ( $self->$method ) {
                        if ( defined $hashref->{$primary_key} ) {
                            my $id = $hashref->{$primary_key};
                            delete $hashref->{$primary_key};
                            $dbrow->$name( { $rel => $id }, { rows => 1 } )
                                ->single->update_or_create_related( $rel,
                                $hashref );
                            next HASHREF;

                        }
                        $dbrow->create_related( $name, { $rel => $hashref } );
                    }
                }
            }
        }
    );
    $dbrow;
}

sub delete {
    my ( $self, $cascade ) = @_;
    confess "No data being fetched from storage: nothing to delete\n"
        if !$self->has_dbrow;
    if ( !$cascade ) {
        $self->chado->txn_do(
            sub {
                $self->chado->resultset( $self->resultset_class )
                    ->search( { pub_id => $self->dbrow->pub_id } )
                    ->delete_all;
            }
        );
    }
    else {
        $self->chado->txn_do(
            sub {
                my $pub = $self->dbrow;
                $pub->pubprops->delete_all;
                $pub->pubauthors->delete_all;
                $pub->pub_dbxrefs->delete_all;
                $pub->pub_relationship_objects->delete_all;
                $pub->pub_relationship_subjects->delete_all;
                $self->dbrow->delete;
            }
        );
    }
    $self->_clear_dbrow;
}

1;    # Magic true value required at end of module

__END__

=head1 NAME

B<Modware::Role::Chado::Reader::BCS::Publication> - [Moose role for persisting publication data to 
chado database]


=head1 SYNOPSIS

with Modware::Role::Chado::Reader::BCS::Publication;


=head1 DESCRIPTION

=for author to fill in:
Write a full description of the module and its features here.
Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=head2 where

=over

=item B<Use:> $obj->where(%conditions)

=item B<Functions:> Returns either a list/iterator with the given conditions. By default,
the conditions are expected to be joined together with ' AND
                    ' clause. However,  it could be
changed using the I<clause> options.

=item B<Return:> Depending on the context either an array of B<Modware::Publication>
object or an iteartor.

=item B<Args:> The following parameters could be passed as key value pairs.

=over

=item id : Database primary key of the reference

=item first_name

=item last_name

=item pubmed_id

=item doi

=item medline_id

=item title

=item journal

=item issue

=item publisher

=item mesh_terms : List of words

=back

=head3 Modifiers for the conditions search

=over

=item clause: B<AND> or B<OR>,  default is AND

=item partial: If set to true(1),  all the conditions matches will be partial. 

=back

=back


=head2 count

=over

=item B<Use:> count(%conditions)

=item B<Functions:> Fetches number of records with the given conditions.

=item B<Return:> Integer

=item B<Args:> Identical to L<where> method.

=back


=head2 first

=over

=item B<Use:> first(%conditions)

=item B<Functions:> Returns the first matching publiction.

=item B<Return:> Modware::Publication object.

=item B<Args:> Identical to L<where> method.

=back


=head2 last

=over

=item B<Use:> last(%conditions)

=item B<Functions:> Returns the last matching publiction.

=item B<Return:> Modware::Publication object.

=item B<Args:> Identical to L<where> method.

=back


=head2 exclude

Inverse of B<where> method.

=head2 find

Alias to B<where> method.



=head1 DIAGNOSTICS

=for author to fill in:
List every single error and warning message that the module can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
A full explanation of any configuration system(s) used by the
module, including the names and locations of any configuration
files, and the meaning of any environment variables or properties
that can be set. These descriptions must also include details of any
configuration language used.

B<Modware::Chado::Reader::BCS::Publication> requires no configuration files or environment variables.


=head1 INCOMPATIBILITIES

  =for author to fill in:
  A list of any modules that this module cannot be used in conjunction
  with. This may be due to name conflicts in the interface, or
  competition for system or program resources, or due to internal
  limitations of Perl (for example, many modules that use source code
		  filters are mutually incompatible).

  None reported.


=head1 BUGS AND LIMITATIONS

  =for author to fill in:
  A list of known problems with the module, together with some
  indication Whether they are likely to be fixed in an upcoming
  release. Also a list of restrictions on the features the module
  does provide: data types that cannot be handled, performance issues
  and the circumstances in which they may arise, practical
  limitations on the size of data sets, special cases that are not
  (yet) handled, etc.

  No bugs have been reported.Please report any bugs or feature requests to
  dictybase@northwestern.edu



=head1 TODO

  =over

  =item *

  [Write stuff here]

  =item *

  [Write stuff here]

  =back


=head1 AUTHOR

  I<Siddhartha Basu>  B<siddhartha-basu@northwestern.edu>


=head1 LICENCE AND COPYRIGHT

  Copyright (c) B<2003>, Siddhartha Basu C<<siddhartha-basu@northwestern.edu>>. All rights reserved.

  This module is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

  BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
  FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
  OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
  PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
  EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
  ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
  YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
  NECESSARY SERVICING, REPAIR, OR CORRECTION.

  IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
  WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
  REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
  LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
  OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
  THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
		  RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
		  FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
  SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
  SUCH DAMAGES.



