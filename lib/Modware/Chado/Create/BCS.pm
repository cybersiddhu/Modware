package Modware::Chado::Create::BCS;

# Other modules:
use strict;
use namespace::autoclean;
use Scalar::Util qw/blessed/;
use Carp;
use Moose;

extends 'Moose::Object';

# Module implementation
#

sub create {
	my ($class,  %arg) = @_;
	croak "need arguments for creating object\n" if scalar keys %arg == 0;
	croak "cannot be called on class instance\n" if blessed $class;
	return $class->new(%arg)->save;
}


1;    # Magic true value required at end of module

__END__

=head1 NAME

B<Modware::Chado::Query::BCS> - [BCS based base class for modware'
            s search modules]


=head1 SYNOPSIS

extends 'Modware::Chado::Query::BCS';

=head1 METHODS

=head2  rearrange_nested_query

=over

=item 

Builds up a nested hash for querying with L<DBIx::Class>

=item

$class->rearrange_nested_query(\%attr, $clause[AND|OR], $match[exact|partial] );

=back


=head2 rearrange_query

Builds up a hash for query with the B<search> method of L<DBICs resultset|DBIx::Class::ResultSet>

Same options as the previous method


=head2 count

Counts the number of objects returned

=head2 find

Searches by primary key and retrieves a single object. The primary key column is
determined by the B<resultset_name> attribute value as set by the inheriting classes.

=head1 ATTRIBUTES

=head2  chado

Keeps a L<Bio::Chado::Schema> object.


=head2 source

Unique datasource name to which the schema object in L</chado> attribute will be connected


=head2 params_map

Keeps a map between search parameters and database column,  have to be set by the
subclass.

=over

=item

allowed_params: List of available parameters for searching.

=item

param_value($val): get the column name

=item

has_param_value($val): check for the presence of a parameter.

=back


=head2 related_params_map

Similar in nature to params_map,  however it contains maps to related tables.

Must be set by the inheriting class

=over

=item

allowed_related_params

=item

related_param_value($val)

=item

has_related_param_value($val)

=back


=head2 data_class

The data object class that will be returned after search. B<Should> be set by inheriting
class.


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


