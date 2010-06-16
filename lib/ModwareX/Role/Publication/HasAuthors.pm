package ModwareX::Role::Publication::HasAuthors;

# Other modules:
use Carp;
use Moose::Role;
use MooseX::Params::Validate;
use MooseX::Aliases;
use aliased 'ModwareX::Publication::Author';
use ModwareX::Types::Publication qw/PubAuthor/;

with 'ModwareX::Role::Collection::HasArray';

# Module implementation
#

sub authors { $_[0]->all }

sub add_author {
    my $self = shift;
    my ($author)
        = pos_validated_list( \@_, { isa => PubAuthor, coerce => 1 } );

    if ( !$author->has_rank ) {
        my $total = $self->total;
        $author->rank( $total == 0 ? 1 : $total + 1 );
        $self->add_to_collection($author);
        return;
    }
    my $element = $self->find_from_collection(
        sub {
            $_->rank == $author->rank;
        }
    );
    if ($element) {
        my $msg =  "Author with identical rank ** ", $element->rank;
        $msg .= " is already present in the collection\n";
        $msg .=  "It is recomended not to add the rank to the authors before adding to collection\n";
        $msg .= "Look at the documentation of the authors collection module\n";
        croak $msg;
    }

    $self->add_to_collection($author);

    #sort the collection by rank
    $self->sort_collection( sub { $_[0]->rank <=> $_[1]->rank } );
}

alias next_author => 'next';

1;    # Magic true value required at end of module

__END__

=head1 NAME

<ModwareX::Publication::Role::HasAuthors> - [Role for managing collection of authors]


=head1 VERSION

This document describes <ModwareX::Publication::Authors> version 0.0.1


=head1 SYNOPSIS

with 'ModwareX::Publication::Role::HasAuthors';

# -- then check for methods it install in your class


=head1 DESCRIPTION

Consuming this Moose role allows your class to maintain a collection of authors(in terms
of ModwareX::Publication::Author). For details look at the methods that get installed in
the class.

The author collections are sorted according to author's rank. By default,  the authors are
ranked according to the order they are added in the collection. If the author is ranked,
the collection is resorted accordingly.


=head1 INTERFACE 

=head2 next_author

=head2 authors

=over

=item B<Use:> $collection->authors;

=item B<Functions:> List of authors

=item B<Return:> Array of ModwareX::Publication::Author objects

=item B<Args:> None

=back

=head2 add_author

=over

=item B<Use:> 

=over

=item  $collection->add_author($author);

=item $collection->add_author( first_name => 'pluto',  last_name => 'marshall',
initials => 'Jr.');

=back

=item B<Functions:> Add an author to the collection

=item B<Return:> None.

=item B<Args:> ModwareX::Publication::Author object or hash with author properties

=back


=head1 DIAGNOSTICS

=over

=item C<< Author with identical rank is already present in the collection >>

Two authors with identical rank is not allowed in the collection.

=back


=head1 CONFIGURATION AND ENVIRONMENT

B<ModwareX::Publication::Authors> requires no configuration files or environment variables.


=head1 DEPENDENCIES

Look at Build.PL

=head1 INCOMPATIBILITIES

  None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.Please report any bugs or feature requests to
dictybase@northwestern.edu

Does not allow to remove item from the collection



=head1 TODO

=over

=item *

API to remove item from collection

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



