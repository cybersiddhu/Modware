package Modware::Meta::Chado::BCS;

# Other modules:
use Moose::Role;
use Modware::Meta::AttributeTraits;
use Carp;
use Bio::Chado::Schema;
use List::Util qw/first/;

# Module implementation
#

has 'resultset' => (
    is  => 'rw',
    isa => 'Str'
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
            'double precision' => 'Float',
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
    my %init_hash = ( %$basic, %$options );
    if ( not defined $options{primary} ) {
        $init_hash{traits} = [qw/Persistent/];
    }
    $meta->add_attribute( $name => %init_hash );
    $meta->_track_attr($name);
}

sub add_chado_prop {
    my ( $meta, $name, %options ) = @_;
    my $basic = $meta->_init_attr_basic( $name, %options );
    my %init_hash = %$basic;    # -- redundant line at this point
    for my $name( qw/cvterm dbxref rank db cv bcs_accessor/) {
    	$init_hash{$name} = $options{$name} if defined $options{$name};
    }

    $init_hash{traits} = [qw/Persistent::Prop/];

    if (not defined $init_hash{bcs_accessor}) {
    	my $bcs_source = $meta->bcs->source($meta->resultset);
    	my $props_bcs;
    	if (defined $init_hash{bcs_resultset}) {
    		$prop_bcs = $init_hash{bcs_resultset};
    	}
    	else {
    		$prop_bcs = $bcs_source->source_name.'prop';
       	}
		$init_hash{bcs_accessor} = first {
				$prop_bcs eq $bcs_source->related_source($_)->source_name
    		} $bcs_source->relationships;
    }

    if (defined $options{lazy}) {
    	$init_hash{lazy} = 1;
    }
    else {
        $init_hash{predicate} = 'has_' . $name;
    }
}

sub _init_attr_basic {
    my ( $meta, $name, %options ) = @_;
    if ( first { $name eq $_ } $meta->_tracked_attrs ) {
        croak "$name is duplicate chado attribute,  already added\n";
    }

    my $method = $options{column} ? $options{column} : $name;
    my %init_hash;
    $init_hash{is}     = 'rw';
    $init_hash{column} = $options{column} if defined $options{column};
    $init_hash{isa}    = $options{isa} || $meta->_infer_isa($method);
    return \%init_hash;
}

sub _init_attr_optional {
    my ( $meta, $name, %options ) = @_;
    my $method = $options{column} ? $options{column} : $name;
    my %init_hash;
    if ( defined $options{lazy} ) {
        $init_hash{lazy}    = 1;
        $init_hash{default} = sub {
            my ($self) = @_;
            return $self->dbrow->$method;
        };
    }
    else {
        $init_hash{predicate} = 'has_' . $name;
    }
    return \%init_hash;
}

sub _infer_isa {
    my ( $meta, $column ) = @_;
    my $col_hash
        = $meta->bcs->source( $meta->resultset )->column_info($column);

    if ( defined $col_hash->{data_type} ) {
        return $meta->_has_type_map( $col_hash->{data_type} )
            ? $meta->_dbic2moose_type( $col_hash->{data_type} )
            : 'Str';
    }
    return 'Str';
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



