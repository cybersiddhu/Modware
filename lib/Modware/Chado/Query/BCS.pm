package Modware::Chado::Query::BCS;

# Other modules:
use Moose;
use MooseX::ClassAttribute;
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
    default => sub { {} },
    lazy    => 1,
    handles => {
        allowed_params => 'keys',
        get_value      => 'get'
    }
);

class_has 'data_class' => (
    is  => 'rw',
    isa => 'Str',
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
    $class->find(%arg)->count;
}

__PACKAGE__->meta->make_immutable;

1;    # Magic true value required at end of module

__END__

=head1 NAME

B<Modware::Chado::Query::BCS> - [Base class for modware's search modules]


=head1 SYNOPSIS

extends 'Modware::Chado::Query::BCS';


=head1 METHODS

=head2  rearrange_nested_query

=head2 rearrange_query

=head2 count

=head1 ATTRIBUTES

=head2  chado

=head2 source

=head2 params_map

=head2 data_class

Should be overridden


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





