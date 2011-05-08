package Modware::Meta::Chado::BCS;

# Other modules:
use Moose::Role;
use Modware::Meta::AttributeTraits;
use Carp;
use Bio::Chado::Schema;
use List::Util qw/first/;
use Class::MOP;

# Module implementation
#

has 'base_namespace' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'Modware'
);

has 'bcs_resultset' => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_bcs_resultset',
    trigger   => sub {
        my ( $self, $value ) = @_;
        $self->bcs_source( $self->bcs->source($value) );
    }
);

has 'bcs_source' => (
    is      => 'rw',
    isa     => 'DBIx::Class::ResultSource',
    trigger => sub {
        my ( $self, $source ) = @_;
        my ($col) = $source->primary_columns;
        $self->pk_column($col);
    }
);

has 'pk_column' => (
    is  => 'rw',
    isa => 'Str',
);

has '_attr_stack' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    traits  => [qw/Array/],
    default => sub { [] },
    handles => {
        '_track_attr'    => 'push',
        '_tracked_attrs' => 'elements'
    }
);

has '_method_map' => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [qw/Hash/],
    default => sub { {} },
    lazy    => 1,
    handles => {
        '_method2class'         => 'get',
        '_add_method2class'     => 'set',
        '_clear_method2classes' => 'clear'
    }
);

has 'bcs' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'Bio::Chado::Schema'
);

has '_column_map' => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [qw/Hash/],
    default => sub {
        return {
            'integer'          => 'Int',
            'text'             => 'Str',
            'boolean'          => 'Bool',
            'varchar'          => 'Str',
            'char'             => 'Str',
            'smallint'         => 'Int',
            'double precision' => 'Num',
            'timestamp'        => 'Str'
        };
    },
    handles => {
        '_dbic2moose_type' => 'get',
        '_has_type_map'    => 'defined',
        '_add_type_map'    => 'set'
    }
);

sub add_column {
    my ( $meta, $name, %options ) = @_;
    my $basic = $meta->_init_attr_basic( $name, %options );
    my $optional = $meta->_init_attr_optional( $name, %options );
    my %init_hash = ( %$basic, %$optional );
    my $method;
    if ( defined $options{column} ) {
        $method = $options{column};
        $init_hash{column} = $options{column};
    }
    else {
        $method = $name;
    }

    $init_hash{default} = sub {
        my ($self) = @_;
        if ( !$self->new_record ) {
            return $self->dbrow->$method;
        }
    };

    if ( defined $options{primary} ) {
        $init_hash{is} = 'ro';
    }
    else {
        $init_hash{trigger} = sub {
            my ( $self, $value ) = @_;
            if ( $self->new_record ) {
                $self->_add_to_mapper( $method, $value );
            }
            else {
                $self->dbrow->$method($value);
            }
        };
    }
    $init_hash{traits} = [qw/Persistent/];
    $meta->add_attribute( $name => %init_hash );
    $meta->_track_attr($name);
}

sub add_chado_prop {
    my ( $meta, $name, %options ) = @_;
    my $basic = $meta->_init_attr_basic( $name, %options );
    my %init_hash = %$basic;    # -- redundant line at this point
    for my $name (qw/cvterm dbxref rank db cv bcs_accessor/) {
        $init_hash{$name} = $options{$name} if defined $options{$name};
    }

    my $bcs_accessor;
    if ( not defined $init_hash{bcs_accessor} ) {
        my $bcs_source = $meta->bcs_source;
        my $prop_bcs;
        if ( defined $init_hash{bcs_resultset} ) {
            $prop_bcs = $init_hash{bcs_resultset};
        }
        else {
            $prop_bcs = $bcs_source->source_name . 'prop';
        }
        $bcs_accessor = first {
            $prop_bcs eq $bcs_source->related_source($_)->source_name;
        }
        $bcs_source->relationships;
    }

    if ( defined $options{lazy} ) {
        $init_hash{lazy}    = 1;
        $init_hash{default} = sub {
            my ($self) = @_;
            $self->dbrow->$bcs_accessor(
                { 'type.name' => $init_hash{cvterm} },
                { join        => 'type' } )->first->value
                if $self->dbrow->$bcs_accessor;
        };
    }

    $init_hash{predicate}    = 'has_' . $name;
    $init_hash{isa}          = 'Maybe[Str]';
    $init_hash{bcs_accessor} = $bcs_accessor;
    $init_hash{traits}       = [qw/Persistent::Prop/];
    $meta->add_attribute( $name => %init_hash );
    $meta->_track_attr($name);
}

sub add_chado_multi_props {
    my ( $meta, $name, %options ) = @_;
    my $basic = $meta->_init_attr_basic( $name, %options );
    my %init_hash = %$basic;    # -- redundant line at this point
    for my $name (qw/cvterm dbxref rank db cv bcs_accessor/) {
        $init_hash{$name} = $options{$name} if defined $options{$name};
    }

    my $bcs_accessor;
    if ( not defined $init_hash{bcs_accessor} ) {
        my $bcs_source = $meta->bcs->source( $meta->bcs_resultset );
        my $prop_bcs;
        if ( defined $init_hash{bcs_resultset} ) {
            $prop_bcs = $init_hash{bcs_resultset};
        }
        else {
            $prop_bcs = $bcs_source->source_name . 'prop';
        }
        $bcs_accessor = first {
            $prop_bcs eq $bcs_source->related_source($_)->source_name;
        }
        $bcs_source->relationships;
    }

    if ( defined $options{lazy} ) {
        $init_hash{lazy}    = 1;
        $init_hash{default} = sub {
            my ($self) = @_;
            my $rs = $self->dbrow->$bcs_accessor(
                { 'type.name' => $init_hash{cvterm} },
                { join        => 'type', cache => 1 }
            );
            if ( $rs->count ) {
                return [ map { $_->value } $rs->all ];
            }
        };
    }

    $init_hash{predicate}    = 'has_' . $name;
    $init_hash{isa}          = 'Maybe[ArrayRef]';
    $init_hash{bcs_accessor} = $bcs_accessor;
    $init_hash{traits}       = [qw/Persistent::MultiProps/];
    $meta->add_attribute( $name => %init_hash );
    $meta->_track_attr($name);
}

sub add_chado_dbxref {
    my ( $meta, $name, %options ) = @_;
    croak "db parameter is required\n" if not defined $options{db};
    my $rel_name = '_' . $name;
    $meta->add_belongs_to(
        $rel_name,
        bcs_accessor => 'dbxref',
        class        => 'Modware::Chado::Dbxref'
    );

    my %init_hash = %{ $meta->_init_attr_basic( $name, %options ) };
    $init_hash{isa}     = 'Maybe[Str]';
    $init_hash{lazy}    = 1;
    $init_hash{default} = sub {
        my ($self) = @_;
        if ( !$self->new_record ) {
            if ( my $rel_obj = $self->$rel_name ) {
                return $rel_obj->accession;
            }
        }
    };
    $init_hash{trigger} = sub {
        my ( $self, $value, $old_value ) = @_;
        Class::MOP::load_class('Modware::Chado::Db');
        Class::MOP::load_class('Modware::Chado::Dbxref');

        my $chado = $self->chado;

        ## -- in case the attribute is getting updated
        if ( defined $old_value and ( $old_value ne $value ) ) {
            my $row = $chado->resultset('General::Dbxref')
                ->find( { accession => $old_value } );
            if ($row) {
                ## -- add the new value
                $row->accession($value);
                ## -- add to the parent object
                $self->$rel_name(
                    Modware::Chado::Dbxref->new( dbrow => $row ) );
                return;
            }
        }

        my $dbxref = Modware::Chado::Dbxref->new( accession => $value );
        $dbxref->version( $options{version} ) if defined $options{version};
        $dbxref->description( $options{description} )
            if defined $options{description};
        my $dbrow = $chado->resultset('General::Db')
            ->find( { name => $options{db} } );
        my $db
            = $dbrow
            ? Modware::Chado::Db->new( dbrow => $dbrow )
            : Modware::Chado::Db->new( name  => $options{db} );
        $dbxref->db($db);
        $self->$rel_name($dbxref);
    };
    $init_hash{predicate} = 'has_' . $name;
    $meta->add_attribute( $name => %init_hash );
    $meta->_track_attr($name);
}

sub add_chado_secondary_dbxref {
    my ( $meta, $name, %options ) = @_;

    my %init_hash = %{ $meta->_init_attr_basic( $name, %options ) };
    $init_hash{isa}       = 'Maybe[Str]';
    $init_hash{predicate} = 'has_' . $name;
    $init_hash{traits}    = [qw/Persistent::Dbxref::Secondary/];
    $init_hash{predicate} = 'has_' . $name;

    my $bcs_source      = $meta->bcs_source;
    my $has_many_source = $bcs_source->source_name . 'Dbxref';
    $init_hash{bcs_hm_accessor} = first {
        $has_many_source eq $bcs_source->related_source($_)->source_name;
    }
    $bcs_source->relationships;

    for my $name (qw/db version description/) {
        $init_hash{$name} = $options{$name} if defined $options{$name};
    }
    if ( defined $options{lazy} ) {
        $init_hash{lazy}    = 1;
        $init_hash{default} = sub {
            my ($self) = @_;
            my $method = $init_hash{bcs_hm_accessor};
            my $query;
            for my $prop (qw/version description/) {
                $query->{$prop} = $init_hash{$name}
                    if defined $init_hash{$name};
            }
            $query->{'db.name'} = $init_hash{db};
            my $rs = $self->dbrow->$method->search_related(
                'dbxref', $query,
                {   join  => 'db',
                    cache => 1
                }
            );
            if ( $rs->count ) {
                return $rs->first->accession;
            }

        };
    }
    $meta->add_attribute( $name => %init_hash );
    $meta->_track_attr($name);
}

sub add_chado_multi_dbxrefs {
    my ( $meta, $name, %options ) = @_;

    my %init_hash = %{ $meta->_init_attr_basic( $name, %options ) };
    $init_hash{isa}       = 'Maybe[ArrayRef]';
    $init_hash{predicate} = 'has_' . $name;
    $init_hash{traits}    = [qw/Persistent::MultiDbxrefs/];
    $init_hash{predicate} = 'has_' . $name;

    my $bcs_source      = $meta->bcs_source;
    my $has_many_source = $bcs_source->source_name . 'Dbxref';
    $init_hash{bcs_hm_accessor} = first {
        $has_many_source eq $bcs_source->related_source($_)->source_name;
    }
    $bcs_source->relationships;

    for my $name (qw/db version description/) {
        $init_hash{$name} = $options{$name} if defined $options{$name};
    }
    if ( defined $options{lazy} ) {
        $init_hash{lazy}    = 1;
        $init_hash{default} = sub {
            my ($self) = @_;
            my $method = $init_hash{bcs_hm_accessor};
            my $query;
            for my $prop (qw/version description/) {
                $query->{$prop} = $init_hash{$name}
                    if defined $init_hash{$name};
            }
            $query->{'db.name'} = $init_hash{db};
            my $rs = $self->dbrow->$method->search_related(
                'dbxref', $query,
                {   join  => 'db',
                    cache => 1
                }
            );
            if ( $rs->count ) {
                return [ map { $_->accession } $rs->all ];
            }

        };
    }
    $meta->add_attribute( $name => %init_hash );
    $meta->_track_attr($name);
}

sub add_chado_type {
    my ( $meta, $name, %options ) = @_;
    my %init_hash = %{ $meta->_init_attr_basic( $name, %options ) };
    $init_hash{isa} = 'Str';
    for my $name (qw/dbxref db cv column/) {
        $init_hash{$name} = $options{$name} if defined $options{$name};
    }
    if ( defined $options{lazy} ) {
        $init_hash{default} = sub {
            my ($self) = @_;
            return $self->dbrow->type->name;
        };
    }
    else {
        $init_hash{predicate} = 'has_' . $name;
    }
    $init_hash{traits} = [qw/Persistent::Type/];
    $meta->add_attribute( $name => %init_hash );
    $meta->_track_attr($name);
}

sub _init_attr_basic {
    my ( $meta, $name, %options ) = @_;
    if ( first { $name eq $_ } $meta->_tracked_attrs ) {
        croak "$name is duplicate chado attribute,  already added\n";
    }
    my %init_hash;
    $init_hash{is} = 'rw';
    return \%init_hash;
}

sub _init_attr_optional {
    my ( $meta, $name, %options ) = @_;
    my %init_hash;
    my $method = $options{column} ? $options{column} : $name;
    $init_hash{isa}        = $options{isa} || $meta->_infer_isa($method);
    $init_hash{predicate}  = 'has_' . $name;
    $init_hash{lazy}       = 1;
    $init_hash{lazy_fetch} = 1 if defined $options{lazy_fetch};
    return \%init_hash;
}

sub _infer_isa {
    my ( $meta, $column ) = @_;
    my $col_hash
        = $meta->bcs->source( $meta->bcs_resultset )->column_info($column);

    my $type = 'Str';
    if ( defined $col_hash->{data_type} ) {
        if ( $meta->_has_type_map( $col_hash->{data_type} ) ) {
            $type = $meta->_dbic2moose_type( $col_hash->{data_type} );
        }
    }

    if ( defined $col_hash->{is_nullable}
        and ( $col_hash->{is_nullable} == 1 ) )
    {
        $type = 'Maybe[' . $type . ']';
    }
    return $type;
}

1;    # Magic true value required at end of module

__END__

=head1 NAME

<MODULE NAME> - [One line description of module's purpose here]


=head1 VERSION

This document describes <MODULE NAME> version 0.0.1


=head1 SYNOPSIS

use <MODULE NAME>;

=for author to fill in:
Brief code example(s) here showing commonest usage(s).
This section will be as far as many users bother reading
so make it as educational and exeplary as possible.


=head1 DESCRIPTION

=for author to fill in:
Write a full description of the module and its features here.
Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=for author to fill in:
Write a separate section listing the public components of the modules
interface. These normally consist of either subroutines that may be
exported, or methods that may be called on objects belonging to the
classes provided by the module.

=head2 <METHOD NAME>

=over

=item B<Use:> <Usage>

[Detail text here]

=item B<Functions:> [What id does]

[Details if neccessary]

=item B<Return:> [Return type of value]

[Details]

=item B<Args:> [Arguments passed]

[Details]

=back

=head2 <METHOD NAME>

=over

=item B<Use:> <Usage>

[Detail text here]

=item B<Functions:> [What id does]

[Details if neccessary]

=item B<Return:> [Return type of value]

[Details]

=item B<Args:> [Arguments passed]

[Details]

=back


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

<MODULE NAME> requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
A list of all the other modules that this module relies upon,
  including any restrictions on versions, and an indication whether
  the module is part of the standard Perl distribution, part of the
  module's distribution, or must be installed separately. ]

  None.


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



