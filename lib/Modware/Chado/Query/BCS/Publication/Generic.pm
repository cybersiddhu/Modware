package Modware::Chado::Query::BCS::Publication::Generic;

# Other modules:
use namespace::autoclean;
use Moose;
use MooseX::ClassAttribute;
use Module::Load;
use Data::Dumper::Concise;
use aliased 'Modware::Collection::Iterator::BCS::ResultSet';
extends 'Modware::Chado::Query::BCS';

# Module implementation
#
class_has 'distinct_columns' => (
    isa        => 'ArrayRef',
    is         => 'ro',
    lazy_build => 1
);

sub _build_distinct_columns {
    my $class  = shift;
    my $source = $class->chado->source( $class->resultset_name );
    return [ $source->primary_columns ];
}

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
            initials   => 'pubauthors.givennames',
            status     => 'pubprops.value',
        };
    },
);

before 'search' => sub {
    my ( $class, %arg ) = @_;
    for my $name (
        qw/query_options joins relations search_attributes
        nested_search_attributes args/
        )
    {
        my $method = 'clear_' . $name;
        $class->$method;
    }
    $class->clause('and');
    $class->full_text(0);
    $class->add_arg( $_, $arg{$_} ) for keys %arg;
    $class->query_engine->add_query_hook(
        'title',
        sub {
            my $class = shift;
            $class->add_blob_column( 'title', 1 );
            $class->add_blob_column('pubprops.value',  1);
        }
    );
};

sub search {
    my ($class) = @_;
    my $cond = $class->get_arg_value('cond');
    $class->clause( lc $cond->{clause} ) if defined $cond->{clause};
    $class->full_text(1) if defined $cond->{full_text};

    my ( $nested, $where, $query );

PARAM:
    for my $param (
        ( $class->allowed_params, $class->allowed_related_params ) )
    {
        next if !$class->has_arg($param);

        ## -- code block for joining the relation
        if ( $class->has_related_param_value($param) ) {
            $class->related_query(1);
            if ( !$class->has_option('cache') ) {
                $class->add_option( 'cache',    1 );
                $class->add_option( 'columns',  $class->distinct_columns );
                $class->add_option( 'distinct', 1 );
            }
            if ( $param ne 'author' ) {
                my $relation
                    = ( ( split /\./, $class->related_param_value($param) ) )
                    [0];
                $class->handle_relation($relation);
                $class->handle_query_attr( $class->related_param2col($param),
                    $param, $relation );
                next PARAM;
            }
            ## -- hardcoded for author as it implies bunch of columns
            if ( $param eq 'author' ) {
                $class->handle_relation('pubauthors');
                $class->handle_nested_query_attr(
                    $class->related_param2col($param),
                    $param, 'pubauthors' );
                $nested = $class->rearrange_nested_query;
                next PARAM;
            }
        }
        $class->handle_query_attr( $class->param2col($param), $param );
    }

    $where = $class->rearrange_query if $class->search_attributes;

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
    my $rs;
    my $options = $class->query_option;
    $options->{join} = [ $class->all_relations ];

    if ( $class->related_query ) {
        my $inside_rs = $class->chado->resultset('Pub::Pub')
            ->search( $query, $options );
        $rs = $class->chado->resultset('Pub::Pub')->search(
            {   pub_id =>
                    { 'IN' => $inside_rs->get_column('pub_id')->as_query }
            }
        );
    }
    else {
        $rs = $class->chado->resultset('Pub::Pub')
            ->search( $query, $options );
    }

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

sub handle_relation {
    my ( $class, $relation ) = @_;
    if ( !$class->has_join($relation) ) {
        $class->add_join($relation,  1);
        if ( $relation eq 'pubprops' ) {
            $class->add_relation( { 'pubprops' => 'type' } );
            return;
        }
        $class->add_relation($relation);
    }
}

sub handle_query_attr {
    my ( $class, $column, $arg, $relation ) = @_;
    if ( !$relation or $relation eq 'pubauthors' ) {
        $class->add_search_attribute( $column, $class->get_arg_value($arg) )
            if !$class->has_search_attribute($column);
        return;
    }

    if ( $relation eq 'pubprops' ) {
        my $value = $class->get_arg_value($arg);
        my $type  = $arg;
        if ( $class->has_search_attribute('pubprops.value') ) {
            my $exist = $class->get_search_attribute('pubprops.value');
            my $type  = $class->get_search_attribute('type.name');
            push @$exist, $value;
            push @$type,  $arg;
        }
        $class->add_search_attribute( 'pubprops.value', $value );
        $class->add_search_attribute( 'type.name',      $type );
    }

}

sub handle_nested_query_attr {
    my ( $class, $columns, $arg, $relation ) = @_;
    $class->add_nested_search_attribute( $_, $class->get_arg_value($arg) )
        for @$columns;
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



