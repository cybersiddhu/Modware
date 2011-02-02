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
        {   first_name => 'pubauthors.givennames',
            last_name  => 'pubauthors.surname',
            initials   => 'pubauthors.givennames',
            status     => 'pubprops.value',
        };
    },
);

class_has '+related_group_params_map' => (
    default => sub {
        { author =>
                [ map { 'pubauthors.' . $_ } qw/givennames surname suffix/ ]
        };
    }
);

before 'search' => sub {
    my ($class) = @_;
    $class->query_engine->add_query_hook(
        'title',
        sub {
            my $class = shift;
            $class->add_blob_column( 'title',          1 );
            $class->add_blob_column( 'pubprops.value', 1 );
        }
    );
};

sub handle_pubprops {
    my ( $class, $relation ) = @_;
    $class->add_relation( { 'pubprops' => 'type' } );
}

sub handle_pubprops_attr {
    my ( $class, $column, $arg, $relation ) = @_;
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

sub generate_resultset {
    my ( $class, $query, $options ) = @_;
    my $rs;
    if ( $class->related_query ) {
        my $inside_rs = $class->resource->resultset('Pub::Pub')
            ->search( $query, $options );
        $rs = $class->resource->resultset('Pub::Pub')->search(
            {   pub_id =>
                    { 'IN' => $inside_rs->get_column('pub_id')->as_query }
            }
        );
    }
    else {
        $rs = $class->resource->resultset('Pub::Pub')
            ->search( $query, $options );
    }
    return $rs;
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



