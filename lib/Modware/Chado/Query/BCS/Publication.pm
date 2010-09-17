package Modware::Chado::Query::BCS::Publication;

# Other modules:
use Moose;
use MooseX::ClassAttribute;
use Module::Load;
use aliased 'Modware::Collection::Iterator::BCS::ResultSet';
use namespace::autoclean;
extends 'Modware::Chado::Query::BCS';

# Module implementation
#

#this should be defined for the find method to work
class_has '+resultset_name' => ( default => 'Pub::Pub' );

class_has '+params_map' => (
    default => sub {
        {   journal => 'series_name',
            title   => 'title',
            year    => 'pyear',
        };
    }
);

class_has '+related_params_map' => (
    default => sub {
        {   author =>
                [ map { 'pubauthors.' . $_ } qw/givennames surname suffix/ ],
            first_name => 'pubauthors.givennames',
            last_name  => 'pubauthors.surname',
            initials   => 'pubauthors.givennames'
        };
    },
);

sub search {
    my ( $class, %arg ) = @_;
    my $clause = $arg{cond}->{clause} ? lc $arg{cond}->{clause} : 'and';
    my $match_type = $arg{cond}->{match} ? lc $arg{cond}->{match} : 'partial';

    my ( $nested, $where, $query, $attrs );
    my $options = {};

PARAM:
    for my $param (
        ( $class->allowed_params, $class->allowed_related_params ) )
    {
        next if not defined $arg{$param};

        ## -- code block for joining the pubauthor table
        if ( $class->has_related_param_value($param) ) {
            if ( not defined $options->{join} ) {
                $options->{join}     = 'pubauthors';
                $options->{cache}    = 1;
                $options->{prefetch} = 'pubauthors';
            }
            if ( $param eq 'author' ) {
                my $author_attr = { map { $_ => $arg{$param} }
                        @{ $class->related_param_value($param) } };
                $nested = $class->rearrange_nested_query( $author_attr, 'or',
                    $match_type );
                next PARAM;
            }
            $attrs->{ $class->related_param_value($param) } = $arg{$param};
            next PARAM;
        }
        $attrs->{ $class->param_value($param) } = $arg{$param};
    }

    $where = $class->rearrange_query( $attrs, $clause, $match_type );
    if ( $nested and $where ) {
        $query = { %$nested, %$where };
    }
    elsif ($nested) {
        $query = $nested;
    }
    else {
        $query = $where;
    }

# - If you want to know what's being done for building the query hash ,  please do a dump
# - of the structure and also read the query syntax for DBIx::Class module
    my $rs = $class->chado->resultset('Pub::Pub')->search( $query, $options );
    if ( wantarray() ) {
        load $class->data_class;
        return map { $class->data_class->new( dbrow => $_ ) } $rs->all;
    }

    ResultSet->new(
        collection        => $rs,
        data_access_class => $class->data_class,
        search_class      => $class
    );
}

__PACKAGE__->meta->make_immutable;

1;    # Magic true value required at end of module

__END__

=head1 NAME

B<Modware::Chado::Query::BCS::Publication> - [Common module for searching publications]


=head1 SYNOPSIS

extends Modware::Chado::Query::BCS::Publication;

Recommended not to be used directly. It is being used by B<Modware::Publication>

=head1 DESCRIPTION

Resusable search class for querying publication data in chado.

=head1 METHODS 

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


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
A full explanation of any configuration system(s) used by the
module, including the names and locations of any configuration
files, and the meaning of any environment variables or properties
that can be set. These descriptions must also include details of any
configuration language used.


=head1 INCOMPATIBILITIES

  =for author to fill in:
  A list of any modules that this module cannot be used in conjunction
  with. This may be due to name conflicts in the interface, or
  competition for system or program resources, or due to internal
  limitations of Perl (for example, many modules that use source code
		  filters are mutually incompatible).



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



