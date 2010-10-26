package Modware::Publication::Author;

# Other modules:
use namespace::autoclean;
use Moose;
use MooseX::Types::Moose qw/Int Str Bool/;
use Modware::Types qw/CleanStr Toggler/;
use Modware::Meta;

# Module implementation
#

has 'id' => (
    is        => 'rw',
    isa       => Int,
    predicate => 'has_author_id',
);

has 'first_name' => (
    is        => 'rw',
    isa       => CleanStr,
    predicate => 'has_first_name',
    coerce    => 1
);

has 'initials' => (
    is        => 'rw',
    isa       => CleanStr,
    predicate => 'has_initials',
    coerce    => 1
);

has 'last_name' => (
    is        => 'rw',
    isa       => CleanStr,
    coerce    => 1,
    predicate => 'has_last_name',
    traits    => [qw/Persistent/],
    column    => 'surname'
);

has 'suffix' => (
    is     => 'rw',
    isa    => 'Maybe[Str]',
    traits => [qw/Persistent/]
);

has 'is_editor' => (
    is      => 'rw',
    isa     => Toggler,
    coerce  => 1,
    default => sub {0},
    traits  => [qw/Persistent/],
    column  => 'editor'
);

has 'is_primary' => (
    is      => 'rw',
    isa     => Bool,
    default => sub {0}
);

after 'is_primary' => sub {
    my ( $self, $value ) = @_;
    $self->rank($value) if $value;
};

has 'rank' => (
    is        => 'rw',
    isa       => 'Int',
    predicate => 'has_rank',
    traits    => [qw/Persistent/]
);

has 'given_name' => (
    is      => 'rw',
    isa     => 'Maybe[Str]',
    traits  => [qw/Persistent/],
    column  => 'givennames',
    lazy => 1, 
    trigger => sub {
        my ( $self, $new, $old ) = @_;
        return if $old and $new eq $old;
        if ( $new =~ /^(\S+)\s+(\S+)$/ ) {
            $self->initials($1);
            $self->first_name($2);
        }
        else {
            $self->first_name($new);
        }

    },
    default => sub {
        my ($self) = @_;
        if ( $self->has_first_name ) {
            if ( $self->has_initials ) {
                return sprintf "%s %s", $self->initials, $self->first_name;
            }
            $self->first_name;
        }
    }
);

1;    # Magic true value required at end of module

__END__

=head1 NAME

B<Modware::Publication::Author> - [Represents an author for a publication]


=head1 VERSION

This document describes B<Modware::Publication::Author> version 0.1


=head1 SYNOPSIS


=for author to fill in:
Brief code example(s) here showing commonest usage(s).
This section will be as far as many users bother reading
so make it as educational and exeplary as possible.


=head1 DESCRIPTION



=head1 INTERFACE 

=for author to fill in:
Write a separate section listing the public components of the modules
interface. These normally consist of either subroutines that may be
exported, or methods that may be called on objects belonging to the
classes provided by the module.

=head2 rank

=over

=item B<Use:> $author->rank(4)

=item B<Functions:> The rank attribute designate order of authors
in a publication which only receives a value after being added in the
B<Modware::Publication::Authors> collection. Setting in the author does not carry any
value. 

=item B<Return:> Integer

=item B<Args:> Integer

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

B<Modware::Publication::Author> requires no configuration files or environment variables.


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



