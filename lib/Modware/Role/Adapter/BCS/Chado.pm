package Modware::Role::Adapter::BCS::Chado;

# Other modules:
use namespace::autoclean;
use Moose::Role;
use Try::Tiny;
use Modware::DataSource::Chado;
use Data::Dumper::Concise;
use Carp;

# Module implementation
#

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
            'Modware::Meta::Attribute::Trait::Persistent::Primary' =>
                sub { $self->read_generic(@_) },
            'Modware::Meta::Attribute::Trait::Persistent::Type' =>
                sub { $self->read_type(@_) },
            'Modware::Meta::Attribute::Trait::Persistent::Dbxref' =>
                sub { $self->read_dbxref(@_) },
            'Modware::Meta::Attribute::Trait::Persistent::Prop' =>
                sub { $self->read_prop(@_) },
            'Modware::Meta::Attribute::Trait::Persistent::MultiProps' =>
                sub { $self->read_multi_props(@_) },
            'Modware::Meta::Attribute::Trait::Persistent::MultiDbxrefs' =>
                sub { $self->read_multi_dbxrefs(@_) },
            'Modware::Meta::Attribute::Trait::Persistent::Dbxref::Secondary'
                => sub { $self->read_sec_dbxrefs(@_) }
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
            'Modware::Meta::Attribute::Trait::Persistent::Type' =>
                sub { $self->create_type(@_) },
            'Modware::Meta::Attribute::Trait::Persistent::Dbxref' =>
                sub { $self->create_dbxref(@_) },
            'Modware::Meta::Attribute::Trait::Persistent::Prop' =>
                sub { $self->create_prop(@_) },
            'Modware::Meta::Attribute::Trait::Persistent::MultiProps' =>
                sub { $self->create_multi_props(@_) },
            'Modware::Meta::Attribute::Trait::Persistent::MultiDbxrefs' =>
                sub { $self->create_multi_dbxrefs(@_) },
            'Modware::Meta::Attribute::Trait::Persistent::Dbxref::Secondary'
                => sub { $self->create_sec_dbxrefs(@_) }

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
            'Modware::Meta::Attribute::Trait::Persistent::Type' =>
                sub { $self->update_type(@_) },
            'Modware::Meta::Attribute::Trait::Persistent::Dbxref' =>
                sub { $self->update_dbxref(@_) },
            'Modware::Meta::Attribute::Trait::Persistent::Prop' =>
                sub { $self->update_prop(@_) },
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
            next TRAIT if $attr->is_lazy;
            my $code = $self->get_read_hook($traits);
            $code->( $attr, $dbrow );
        }
    }
}

sub read_generic {
    my ( $self, $attr, $dbrow ) = @_;
    my $column = $attr->has_column ? $attr->column : $attr->name;
    $attr->set_value( $self, $dbrow->$column ) if defined $dbrow->$column;
}

sub read_type {
    my ( $self, $attr, $dbrow ) = @_;
    $attr->set_value( $self, $dbrow->type->name );
}

sub read_dbxref {
    my ( $self, $attr, $dbrow ) = @_;
    $attr->set_value( $self, $dbrow->dbxref->accession )
        if defined $dbrow->dbxref_id;
}

sub read_prop {
    my ( $self, $attr, $dbrow ) = @_;
    my $method = $attr->bcs_accessor;
    $attr->set_value(
        $self,
        $dbrow->$method( { 'type.name' => $attr->cvterm },
            { join => 'type' } )->first->value
    ) if $dbrow->$method;
}

sub read_multi_props {
    my ( $self, $attr, $dbrow ) = @_;
    my $method = $attr->bcs_accessor;
    my $rs = $dbrow->$method( { 'type.name' => $attr->cvterm },
        { join => 'type', cache => 1 } );
    if ( $rs->count ) {
        $attr->set_value( $self, [ map { $_->value } $rs->all ] );
    }
}

sub read_sec_dbxref {
    my ( $self, $attr, $dbrow ) = @_;
    my $method = $attr->bcs_hm_accessor;
    my $query;
    for my $prop (qw/version description/) {
        my $predicate = 'has_' . $prop;
        $query->{$prop} = $attr->$name if $attr->$predicate;
    }
    $query->{'db.name'} = $attr->db;

    my $rs = $dbrow->$method->search_related( 'dbxref', $query,
        { join => 'db', cache => 1 } );
    if ( $rs->count ) {
        $rs->first->accession;
    }
}

sub read_multi_dbxrefs {
    my ( $self, $attr, $dbrow ) = @_;
    my $method = $attr->bcs_hm_accessor;
    my $query;
    for my $prop (qw/version description/) {
        my $predicate = 'has_' . $prop;
        $query->{$prop} = $attr->$name if $attr->$predicate;
    }
    $query->{'db.name'} = $attr->db;

    my $rs = $dbrow->$method->search_related( 'dbxref', $query,
        { join => 'db', cache => 1 } );
    if ( $rs->count ) {
        $rs->first->accession;
    }
}

sub create_generic {
    my ( $self, $attr ) = @_;
    my $column = $attr->has_column ? $attr->column : $attr->name;
    my $value = $attr->get_value($self);
    $self->_add_to_mapper( $column, $value ) if $value;
}

sub create_type {
    my ( $self, $attr ) = @_;
    my $value = $attr->get_value($self);
    my %data;
    $data{cvterm} = $value;
    $data{dbxref} = $attr->has_dbxref ? $attr->dbxref : $value;
    $data{cv}     = $attr->cv if $attr->has_cv;
    $data{db}     = $attr->db if $attr->has_db;
    $self->_add_to_mapper( $attr->column,
        $self->find_or_create_cvterm_id(%data) );
}

sub create_prop {
    my ( $self, $attr ) = @_;
    my $value = $attr->get_value($self);
    my %data;
    $data{cvterm} = $attr->cvterm;
    $data{dbxref} = $attr->dbxref;
    $data{cv}     = $attr->cv if $attr->has_cv;
    $data{db}     = $attr->db if $attr->has_db;
    $self->_add_to_prop(
        $attr->bcs_accessor,
        {   type_id => $self->find_or_create_cvterm_id(%data),
            value   => $value,
            rank    => $attr->rank
        }
    );

}

sub create_multi_props {
    my ( $self, $attr ) = @_;
    my $value = $attr->get_value($self);
    my %data;
    $data{cvterm} = $attr->cvterm;
    $data{dbxref} = $attr->dbxref;
    $data{cv}     = $attr->cv if $attr->has_cv;
    $data{db}     = $attr->db if $attr->has_db;

    my $rank = $attr->rank;
    for my $prop (@$value) {
        $self->_add_to_prop(
            $attr->bcs_accessor,
            {   type_id => $self->find_or_create_cvterm_id(%data),
                value   => $prop,
                rank    => $rank++
            }
        );
    }
}

sub create_dbxref {
    my ( $self, $attr ) = @_;
    my $value = $attr->get_value($self);
    my %data;
    $data{version}     = $attr->version     if $attr->has_version;
    $data{description} = $attr->description if $attr->has_description;
    $data{accession}   = $value;
    $data{db_id} = $self->find_or_create_db_id( $attr->db );
    $self->_add_to_mapper( 'dbxref', \%data );
}

sub create_sec_dbxref {
    my ( $self, $attr ) = @_;
    my $data;
    $data->{version}     = $attr->version     if $attr->has_version;
    $data->{description} = $attr->description if $attr->has_description;
    $data->{accession}   = $value;
    $data->{db_id} = $self->find_or_create_db_id( $attr->db );
    my $hm_accs = $attr->bcs_hm_accessor;
    $self->_add_to_mapper( $hm_accs => [ { 'dbxref' => $data } ] );
}

sub create_multi_dbxrefs {
    my ( $self, $attr ) = @_;
    my $arr;
    for my $value ( @{ $attr->get_value($self) } ) {
        my $data->{accession} = $value;
        $data->{version}     = $attr->version     if $attr->has_version;
        $data->{description} = $attr->description if $attr->has_description;
        $data->{db_id} = $self->find_or_create_db_id( $attr->db );
        push @$arr, { dbxref => $data };
    }
    my $hm_accs = $attr->bcs_hm_accessor;
    $self->_add_to_mapper( $hm_accs => $arr );
}

sub create {
    my ( $self, %arg ) = @_;

    croak "cannot create a new object which already exist in the database\n"
        if $self->has_dbrow;

    ## -- check for attribute probably will go through require pragma once moose support
    ## -- validation through stack roles
    my $meta = $self->meta;
    if ( !$meta->has_bcs_resultset ) {
        croak "**bcs_resultset** attribute need to be defined\n";
    }

    #$self->do_validation;

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
            my $value = $chado->resultset( $meta->bcs_resultset )
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



