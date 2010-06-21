package Modware::Role::Chado::Reader::BCS::Publication;

use version; our $VERSION = qv('0.1');

# Other modules:
use Moose::Role;
use aliased 'Modware::DataSource::Chado';

# Module implementation
#

has 'chado' => (
    is         => 'rw',
    isa        => 'Bio::Chado::Schema',
    lazy_build => 1
);

sub _build_chado {
    my ($self) = @_;
    my $chado
        = $self->has_source
        ? Chado->handler( $self->source )
        : Chado->handler;
    $chado;
}

has 'dbrow' => (
    is        => 'rw',
    isa       => 'DBIx::Class::Row',
    predicate => 'has_dbrow'
);

has 'cv' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => 'pub_type'
);

has 'cvterm' => ( is => 'rw', isa => 'Str', lazy => 1, default => 'paper' );
has 'db'     => ( is => 'rw', isa => 'Str', lazy => 1, default => 'pubmed' );

sub _build_status {
    return if !$self->has_dbrow;
    my $rs = $self->dbrow->search_related(
        'pubprops',
        {   'type_id' => $self->cvterm_id_by_name('status');
        }
    );
    $rs->first->value if $rs;
}

sub _build_abstract {
    my ($self) = @_;
    return if !$self->has_dbrow;
    my $rs = $self->dbrow->search_related(
        'pubprops',
        {   'type_id' => $self->cvterm_id_by_name('abstract');
        }
    );
    $rs->first->value if $rs;
}

sub _build_title {
    my ($self) = @_;
    $self->dbrow->title if $self->has_dbrow;
}

sub _build_year {
    my ($self) = @_;
    $self->dbrow->pyear if $self->has_dbrow;
}

sub _build_source {
    my ($self) = @_;
    $self->dbrow->pubplace if $self->has_dbrow;
}

sub _build_keywords_stack {
    my ($self) = @_;
    return if !$self->has_dbrow;
    my $rs = $self->dbrow->search_related(
        'pubprops',
        {   'type_id' => {
                -in => $self->cvterm_ids_by_namespace(
                    'dictyBase_literature_topic'
                )
            }
        }
    );
    if ($rs) {
        my $terms = [ map { $_->value } $rs->all ];
        return $terms;
    }
}

has 'pub' => (
    is         => 'rw',
    isa        => 'Bio::Chado::Schema::Pub::Pub',
    lazy_build => 1,
);

sub _build_pub {
    my $self = shift;
    $self->chado->resultset('Pub::Pub')->new( {} );
}

before 'create' => sub {
    my $self = shift;
    my $pub  = $self->pub;
    $pub->uniquename( 'PUB' . int( rand(9999999) ) );
    $pub->type_id( $self->cvterm_id_by_name( $self->type ) );
    $pub->title( $self->title )
        if $self->has_title;
    $pub->pyear( $self->year )      if $self->has_year;
    $pub->pubplace( $self->source ) if $self->has_source;

    my $pubprops;
    push @$pubprops,
        {
        type_id => $self->cvterm_id_by_name('status'),
        value   => $self->status
        };
    push @$pubprops,
        {
        type_id => $self->cvterm_id_by_name('abstract'),
        value   => $self->abstract
        };

    for my $word ( $self->keywords ) {
        push @$pubprops,
            {
            type_id => $self->cvterm_id_by_name($word),
            value   => 'true'
            };
    }
    $pub->pubprops($pubprops) if $pubprops;

    if ( $self->has_authors ) {
        my $authors;
        while ( my $pubauthor = $self->next_author ) {
            push @$authors,
                {
                rank       => $pubauthor->rank,
                editor     => $pubauthor->is_editor,
                surname    => $pubauthor->last_name,
                givennames => $pubauthor->given_name,
                suffix     => $pubauthor->suffix
                };
        }
        $pub->pubauthors($authors);
    }
};

sub create {
    my ($self) = @_;
    try {
        $self->chado->txn_do( sub { $self->pub->insert } );
    }
    catch {
        confess "Issue in inserting publication record: $_";
    };
}

before 'delete' => sub {
    confess "No data being fetched from storage: nothing to delete\n"
        if !$self->has_dbrow;
};

sub delete {
    my ( $self, $cascade ) = @_;
    if ( !$cascade ) {
        try {
            $self->chado->txn_do(
                sub {
                    $self->chado->resultset('Pub::Pub')
                        ->search( { pub_id => $self->dbrow->pub_id } )
                        ->delete_all;
                }
            );
        }
        catch { confess "Unable to delete $_" };
    }
    else {
        try {
            $self->chado->txn_do(
                sub {
                    my $pub = $self->dbrow;
                    $dbrow->pubprops->delete_all;
                    $dbrow->authors->delete_all;
                    $dbrow->pub_dbxrefs->delete_all;
                    $dbrow->pub_relationship_objects->delete_all;
                    $dbrow->pub_relationship_subjects->delete_all;
                    $dbrow->delete;
                }
            );
        }
        catch { confess "Unable to delete $_" };
    }
}

sub update {
}

1;    # Magic true value required at end of module

__END__

=head1 NAME

B<Modware::Chado::Reader::BCS::Publication> - [Module for retrieiving publication from
chado database]


=head1 VERSION

This document describes <Modware::Chado::Reader::BCS::Publication> version 0.1


=head1 SYNOPSIS

use Modware::Chado::Reader::BCS::Publication;


=head1 DESCRIPTION

=for author to fill in:
Write a full description of the module and its features here.
Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=head2 where

=over

=item B<Use:> $obj->where(%conditions)

=item B<Functions:> Returns either a list/iterator with the given conditions. By default,
the conditions are expected to be joined together with ' AND
                        ' clause. However,  it could be
changed using the I<clause> options.

=item B<Return:> Depending on the context either an array of B<Modware::Publication>
object or an iteartor.

=item B<Args:> The following parameters could be passed as key value pairs.

=over

=item id : Database primary key of the reference

=item first_name

=item last_name

=item pubmed_id

=item doi

=item medline_id

=item title

=item journal

=item issue

=item publisher

=item mesh_terms : List of words

=back

=head3 Modifiers for the conditions search

=over

=item clause: B<AND> or B<OR>,  default is AND

=item partial: If set to true(1),  all the conditions matches will be partial. 

=back

=back


=head2 count

=over

=item B<Use:> count(%conditions)

=item B<Functions:> Fetches number of records with the given conditions.

=item B<Return:> Integer

=item B<Args:> Identical to L<where> method.

=back


=head2 first

=over

=item B<Use:> first(%conditions)

=item B<Functions:> Returns the first matching publiction.

=item B<Return:> Modware::Publication object.

=item B<Args:> Identical to L<where> method.

=back


=head2 last

=over

=item B<Use:> last(%conditions)

=item B<Functions:> Returns the last matching publiction.

=item B<Return:> Modware::Publication object.

=item B<Args:> Identical to L<where> method.

=back


=head2 exclude

Inverse of B<where> method.

=head2 find

Alias to B<where> method.



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

B<Modware::Chado::Reader::BCS::Publication> requires no configuration files or environment variables.


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

  [Write stuff here]

  =item *

  [Write stuff here]

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



