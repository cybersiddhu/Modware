package Modware::Chado::Query::BCS::Publication::Pubmed;

# Other modules:
use Moose;
use MooseX::ClassAttribute;
use Module::Load;
use MooseX::Params::Validate;
use namespace::autoclean;
extends 'Modware::Chado::Query::BCS::Publication::Generic';

# Module implementation
#

class_has '+data_class' => ( default => 'Modware::Publication::Pubmed' );

sub find_by_pubmed_id {
    my $class = shift;
    my ($id) = pos_validated_list( \@_, { isa => 'Int' } );
    my $row
        = $class->chado->resultset('Pub::Pub')->find( { uniquename => $id } );
    if ($row) {
        load $class->data_class;
        return $class->data_class->new( dbrow => $row );
    }
}

1;    # Magic true value required at end of module

__END__

=head1 NAME

B<Modware::Chado::Query::BCS::Publication> - [Module for searching publications]


=head1 SYNOPSIS

Not to be used directly. It is being used by B<Modware::Publication>

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



