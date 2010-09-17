package Modware::Chado::Query::BCS;

# Other modules:
use Moose;
use MooseX::ClassAttribute;
use MooseX::Params::Validate;
use Module::Load;
use namespace::autoclean;
use aliased 'Modware::DataSource::Chado';

# Module implementation
#

class_has 'chado' => (
    is         => 'ro',
    isa        => 'Bio::Chado::Schema',
    lazy_build => 1
);

sub _build_chado {
    my ($class) = @_;
    my $chado
        = $class->has_source
        ? Chado->handler( $class->source )
        : Chado->handler;
    $chado;
}

class_has 'source' => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_source'
);

class_has 'params_map' => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [qw/Hash/],
    lazy    => 1,
    default => sub { {} }, 
    handles => {
    	allowed_params => 'keys', 
    	param_value => 'get', 
    	has_param_value => 'defined'
    }
);

class_has 'related_params_map' => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [qw/Hash/],
    lazy    => 1,
    default => sub { {} }, 
    handles => {
    	allowed_related_params => 'keys', 
    	related_param_value => 'get', 
    	has_related_param_value => 'defined'
    }
);


class_has 'data_class' => (
    is  => 'rw',
    isa => 'Str'
);

class_has 'resultset_name' => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_resultset_name'
);

sub rearrange_nested_query {
    my ( $class, $attrs, $clause, $match_type ) = @_;
    $clause     = lc $clause;
    $match_type = lc $match_type;

    my $where;
    for my $param ( keys %$attrs ) {
        push @$where,
            {
              $param => $match_type eq 'exact'
            ? $attrs->{$param}
            : { 'like', '%' . $attrs->{$param} . '%' }
            };
    }
    my $nested_where;
    $nested_where->{ '-' . $clause } = $where;
    $nested_where;
}

sub rearrange_query {
    my ( $class, $attrs, $clause, $match_type ) = @_;
    $clause     = lc $clause;
    $match_type = lc $match_type;

    my $where;
    for my $param ( keys %$attrs ) {
        if ( $clause eq 'and' ) {
            $where->{$param}
                = $match_type eq 'exact'
                ? $attrs->{$param}
                : { 'like', '%' . $attrs->{$param} . '%' };
        }
        else {
            push @$where,
                $match_type eq 'exact'
                ? { $param => $attrs->{$param} }
                : { $param => { 'like', '%' . $attrs->{$param} . '%' } };

        }
    }
    $where;
}

sub count {
    my ( $class, %arg ) = @_;
    $class->search(%arg)->count;
}

sub find {
    my $class = shift;
    my ($id) = pos_validated_list( \@_, { isa => 'Int' } );
    my $row = $class->chado->resultset( $class->resultset_name )->find($id);
    if ($row) {
        load $class->data_class;
        return $class->data_class->new( dbrow => $row );
    }
}

before 'find' => sub {
    my $class = shift;
    confess "resultset_name must be defined in your query class\n"
        if !$class->has_resultset_name;
};

__PACKAGE__->meta->make_immutable;

1;    # Magic true value required at end of module

__END__

=head1 NAME

B<Modware::Chado::Query::BCS> - [BCS based base class for modware's search modules]


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


