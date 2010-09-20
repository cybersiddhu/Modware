package Modware::Publication;

# Other modules:
use Moose;
use MooseX::ClassAttribute;
use Module::Load;
use namespace::autoclean;

# Module implementation
#
with 'Modware::Role::Chado::Builder::BCS::Publication';
with 'Modware::Role::Chado::Writer::BCS::Publication';

with 'Modware::Role::Chado::Builder::BCS::Publication::JournalArticle';
with 'Modware::Role::Chado::Writer::BCS::Publication::JournalArticle';

with 'Modware::Role::Chado::Builder::BCS::Publication::Pubmed';
with 'Modware::Role::Chado::Writer::BCS::Publication::Pubmed';

with 'Modware::Role::Chado::Helper::BCS::Cvterm';
with 'Modware::Role::Chado::Helper::BCS::Dbxref';
with 'Modware::Role::Publication::HasAuthors';
with 'Modware::Role::HasPublication';
with 'Modware::Role::Publication::HasJournalArticle';
with 'Modware::Role::Publication::HasPubmed';

has '+type' => ( default => 'pubmed_journal_article' );

class_has 'query_class' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'Modware::Chado::Query::BCS::Publication::Pubmed'
);

class_has 'query' => (
    default => sub {
        my $q     = __PACKAGE__->query_class;
        load $q;
        $q;
    },
    isa     => 'Str',
    is      => 'rw',
    lazy    => 1,
    handles => [qw/find count search find_by_pubmed_id/]
);

__PACKAGE__->meta->make_immutable;

1;    # Magic true value required at end of module

__END__

=head1 NAME

<Modware::Publication> - [Module for handling publication/bibliographic references]


=head1 SYNOPSIS

use aliased 'Modware::Publication';

 my $itr = Publication->find(....);
 while(my $pub = $itr->next) {
 	print $pub->title,  "\t",  $pub->pubmed_id, "\n";
 }
 my @pubs = Publication->find(....)
 my $count = Publication->count();

 my $pub = Publication->new(title => 'my_title');
 $pub->pubmed_id(43343335);
 $pub->abstract('my new abstract');
 $pub->journal('jbc');
 $pub->add_author($author);
 $pub->create;

 $pub->add_author($author2);
 $pub->update;



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

=item B<Return:> Integer.

=item B<Args:> None

=back


=head2 authors

=over

=item B<Use:> $pub->authors($authors_list)

=item B<Functions:> Get/Set list of authors

=item B<Return:> Arrayref containing Modware::Publication::Author objects

=item B<Args:> Arrayref containing Modware::Publication::Author objects

=back


=head2 add_author

=over

=item B<Use:> $pub->add_author($author) or $pub->add_author($author_hashref)

=item B<Functions:> Add an author to the list 

=item B<Return:> None.

=item B<Args:> Modware::Publication::Author or an hashref(doc later)

=back


=head2 cross_references

=over

=item B<Use:> $pub->cross_references($cross_refs)

=item B<Functions:> Get/Set list of cross_references

 The Modware::Publication object is expected to be already present in the database,  i.e,.
 the object should have a database id. 

=item B<Return:> Arrayref containing Modware::Publication

=item B<Args:> Arrayref containing Modware::Publication

=back


=head2 add_cross_reference

=over

=item B<Use:> $pub->add_cross_reference($cross_ref)

=item B<Functions:> Add a cross_reference to the list

 The Modware::Publication object is expected to be already present in the database,  i.e,.
 the object should have a database id. 

=item B<Return:> Modware::Publication

=item B<Args:> None.

=back


=head2 add_cross_reference

=over

=item B<Use:> $pub->add_cross_reference($cross_ref)

=item B<Functions:> Add a cross_reference to the list

 The Modware::Publication object is expected to be already present in the database,  i.e,.
 the object should have a database id. 

=item B<Return:> Modware::Publication

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

B<Modware::Publication> requires no configuration files or environment variables.


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



