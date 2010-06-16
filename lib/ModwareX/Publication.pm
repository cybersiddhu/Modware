package ModwareX::Publication;


use version; our $VERSION = qv('1.0.0');

# Other modules:
use Moose;

# Module implementation
#
with 'ModwareX::Role::Publication::HasAuthors';
with 'ModwareX::Role::Chado::Writer::BCS::Publication';

# Module implementation
#

has 'abstract' => (
	is => 'rw', 
	isa => 'Maybe[Str]'
	lazy_build => 1
);

has 'title' => (
	is => 'rw', 
	isa => 'Maybe[Str]', 
	lazy_build => 1
);

has 'year' => (
	is => 'rw', 
	isa => 'Maybe[Str]', 
	lazy_build => 1
);

has 'keywords_stack' => (
	is => 'rw', 
	isa => 'Maybe[ArrayRef[Str]]'
	traits => [qw/Array/], 
	lazy_build => 1,
	handles => {
		add_keyword => 'push', 
		keywords => 'elements'
	}
);

has 'source' => (
	is => 'rw', 
	isa => 'Maybe[Str]', 
	lazy_build => 1
);

has 'status' => (
	is => 'rw', 
	isa => 'Maybe[Str]', 
	lazy_build => 1
);

has 'type' => (
	is => 'rw', 
	isa => 'Str', 
	lazy => 1, 
	default => 'paper'
);


no Moose;

1;    # Magic true value required at end of module

__END__

=head1 NAME

<ModwareX::Publication> - [Module for dealing with publication/bibliographic references]


=head1 VERSION

This document describes <ModwareX::Publication> version 0.1


=head1 SYNOPSIS

use <MODULE NAME>;


=head1 DESCRIPTION

=for author to fill in:
Write a full description of the module and its features here.
Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=head2 id

=over

=item B<Use:> $pub->id()

=item B<Functions:> Get the database id of this object. If it is undef then the object is
still not saved in the database. It can also be used as *set* method,  however it is
recommended for internal use only. 

=item B<Return:> Maybe[Str]eger

=item B<Args:> None

=back


=head2 authors

=over

=item B<Use:> $pub->authors($authors_list)

=item B<Functions:> Get/Set list of authors

=item B<Return:> Arrayref containing ModwareX::Publication::Author objects

=item B<Args:> Arrayref containing ModwareX::Publication::Author objects

=back


=head2 add_author

=over

=item B<Use:> $pub->author($author) or $pub->author($author_hashref)

=item B<Functions:> Add an author to the list 

=item B<Return:> None.

=item B<Args:> ModwareX::Publication::Author or an hashref(doc later)

=back


=head2 cross_references

=over

=item B<Use:> $pub->cross_references($cross_refs)

=item B<Functions:> Get/Set list of cross_references

 The ModwareX::Publication object is expected to be already present in the database,  i.e,.
 the object should have a database id. 

=item B<Return:> Arrayref containing ModwareX::Publication

=item B<Args:> Arrayref containing ModwareX::Publication

=back


=head2 add_cross_reference

=over

=item B<Use:> $pub->add_cross_reference($cross_ref)

=item B<Functions:> Add a cross_reference to the list

 The ModwareX::Publication object is expected to be already present in the database,  i.e,.
 the object should have a database id. 

=item B<Return:> ModwareX::Publication

=item B<Args:> None.

=back


=head2 add_cross_reference

=over

=item B<Use:> $pub->add_cross_reference($cross_ref)

=item B<Functions:> Add a cross_reference to the list

 The ModwareX::Publication object is expected to be already present in the database,  i.e,.
 the object should have a database id. 

=item B<Return:> ModwareX::Publication

=item B<Args:> None.

=back


=head2 Other accessors

=over

=item abstract

=item title

=item year

=item format

=item date

=item keywords

=item publisher

=item type

=item status

=item source

=back

=over

B<Not implemented yet>

=item abstract_language

=item abstract_type

=back



=head1 DIAGNOSTICS

=for author to fill in:
List every single error and warning message that the module can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
A full explanation of any configuration system(s) used by the
module, including the names and locations of any configuration
files, and the meaning of any environment variables or properties
that can be set. These descriptions must also include details of any
configuration language used.

B<ModwareX::Publication> requires no configuration files or environment variables.


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


=item *


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



