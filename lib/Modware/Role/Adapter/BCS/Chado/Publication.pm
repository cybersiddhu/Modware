package Modware::Role::Adapter::BCS::Chado::Publication;

# Other modules:
use namespace::autoclean;
use Moose::Role;
use Module::Load;
use Try::Tiny;
use Carp;
use Data::Dumper::Concise;
use DBIx::Class::ResultClass::HashRefInflator;

# Module implementation
#

with 'Modware::Role::Adapter::BCS::Chado';
with 'Modware::Role::Chado::Helper::BCS::WithDataStash' => {
    create_stash_for => [qw/pubprops pubauthors pub_dbxrefs/],
    update_stash_for => {
        has_many     => [qw/pubauthors pubprops/],
        many_to_many => [qw/pub_dbxrefs/]
    }
};

has 'pub_id' => (
    is      => 'ro',
    isa     => 'Maybe[Int]',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return if $self->new_record;
        $self->dbrow->pub_id;
    }
);

has 'resultset_class' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'Pub::Pub'
);

before 'all_read_hooks' => sub {
    my $self = shift;
    $self->add_read_hook(
        'Modware::Meta::Attribute::Trait::Persistent::Pubprop',
        sub { $self->read_pubprop(@_) } );
    $self->add_read_hook(
        'Modware::Meta::Attribute::Trait::Persistent::Pubauthors',
        sub { $self->read_authors(@_) } );
    $self->add_read_hook(
        'Modware::Meta::Attribute::Trait::Persistent::Pubdbxref',
        sub { $self->read_pub_dbxref(@_) } );
    $self->add_read_hook(
        'Modware::Meta::Attribute::Trait::Persistent::Pubprop::Dicty',
        sub { $self->read_dicty_pubprops(@_) } );
};

before 'create' => sub {
    my $self = shift;
    $self->add_create_hook(
        'Modware::Meta::Attribute::Trait::Persistent::Pubprop',
        sub { $self->create_pubprop(@_) } );
    $self->add_create_hook(
        'Modware::Meta::Attribute::Trait::Persistent::Pubauthors',
        sub { $self->create_authors(@_) } );
    $self->add_create_hook(
        'Modware::Meta::Attribute::Trait::Persistent::Pubdbxref',
        sub { $self->create_pub_dbxref(@_) } );
    $self->add_create_hook(
        'Modware::Meta::Attribute::Trait::Persistent::Pubprop::Dicty',
        sub { $self->create_dicty_pubprops(@_) } );
};

before 'update' => sub {
    my $self = shift;
    $self->add_update_hook(
        'Modware::Meta::Attribute::Trait::Persistent::Pubprop',
        sub { $self->update_pubprop(@_) } );
    $self->add_update_hook(
        'Modware::Meta::Attribute::Trait::Persistent::Pubauthors',
        sub { $self->update_authors(@_) } );
    $self->add_update_hook(
        'Modware::Meta::Attribute::Trait::Persistent::Pubdbxref',
        sub { $self->update_pub_dbxref(@_) } );
    $self->add_update_hook(
        'Modware::Meta::Attribute::Trait::Persistent::Pubprop::Dicty',
        sub { $self->update_dicty_pubprops(@_) } );
};

sub read_pubprop {
    my ( $self, $attr, $dbrow ) = @_;
    my $cvterm = $attr->has_cvterm ? $attr->cvterm : $attr->name;
    my $type_id = $self->find_cvterm_id(
        cvterm => $cvterm,
        cv     => $attr->cv,
        db     => $attr->db
    );
    return if !$type_id;    #no record in the database
    my $rs = $dbrow->search_related( 'pubprops', { 'type_id' => $type_id } );
    if ( $rs->count > 0 ) {
        $attr->set_value( $self, $rs->first->value );
    }
}

sub read_pub_dbxref {
    my ( $self, $attr, $dbrow ) = @_;
    my $db = $attr->has_db ? $attr->db : $attr->name;
    my $rs = $dbrow->search_related( 'pub_dbxrefs', {} )
        ->search_related( 'dbxref', { 'db.name' => $db }, { join => 'db' } );
    if ( $rs->count > 0 ) {
        $attr->set_value( $self, $rs->first->accession );
    }
}

sub read_dicty_pubprops {
    my ( $self, $attr, $dbrow ) = @_;
    my $rs = $dbrow->search_related(
        'pubprops',
        { 'cv.name' => $attr->cv },
        { join      => { 'type' => 'cv' } }
    );
    return [] if $rs->count == 0;
    $attr->set_value( $self, [ map { $_->type->name } $rs->all ] );
}

sub read_authors {
    my ( $self, $attr, $dbrow ) = @_;
    my $collection = [];
    my $rs         = $dbrow->pubauthors;
    return $collection if $rs->count == 0;

    my $author_obj = $attr->map_to;
    load $author_obj;
    my %column_map;
    for my $author_attr ( $author_obj->meta->get_all_attributes ) {
        next
            if !$author_attr->does(
            'Modware::Meta::Attribute::Trait::Persistent');
        my $column
            = $author_attr->has_column
            ? $author_attr->column
            : $author_attr->name;
        $column_map{$column} = $author_attr->name;
    }
    while ( my $row = $rs->next ) {
        my $author = $author_obj->new;
        for my $col ( keys %column_map ) {
            my $accessor = $column_map{$col};
            $author->$accessor( $row->$col ) if defined $row->$col;
        }
        push @$collection, $author;
    }
    $attr->set_value( $self, $collection );
}

sub create_pubprop {
    my ( $self, $attr ) = @_;
    my $cvterm = $attr->has_cvterm ? $attr->cvterm : $attr->name;
    my $pubprop = {
        type_id => $self->find_or_create_cvterm_id(
            cvterm => $cvterm,
            cv     => $attr->cv,
            db     => $attr->db
        ),
        value => $attr->get_value($self),
        rank  => $attr->rank
    };
    $self->add_to_insert_pubprops($pubprop);
}

sub create_dicty_pubprops {
    my ( $self, $attr ) = @_;
    for my $value ( @{ $attr->get_value($self) } ) {
        my $pubprop = {
            type_id => $self->find_or_create_cvterm_id(
                cvterm => $value,
                cv     => $attr->cv,
                db     => $attr->db
            ),
            value => 'true',
            rank  => 0
        };
        $self->add_to_insert_pubprops($pubprop);
    }
}

sub create_authors {
    my ( $self, $attr ) = @_;
    my $author_array = $attr->get_value($self);
    my $key          = $attr->association;

    for my $author ( @{$author_array} ) {
        my $author_hash;
    AUTHOR:
        for my $author_attr ( $author->meta->get_all_attributes ) {
            next AUTHOR
                if !$author_attr->does(
                'Modware::Meta::Attribute::Trait::Persistent');
            my $value = $author_attr->get_value($author);
            next if !$value;
            my $column
                = $author_attr->has_column
                ? $author_attr->column
                : $author_attr->name;
            $author_hash->{$column} = $value;
        }
        $self->add_to_insert_pubauthors($author_hash);
    }
}

sub create_pub_dbxref {
    my ( $self, $attr ) = @_;
    my $db = $attr->has_db ? $attr->db : $attr->name;
    $self->add_to_insert_pub_dbxrefs(
        {   dbxref => {
                accession => $attr->get_value($self),
                db_id     => $self->db_id_by_name($db)
            }
        }
    );
}

sub update_pubprop {
    my ( $self, $attr ) = @_;
    my $cvterm = $attr->has_cvterm ? $attr->cvterm : $attr->name;
    my $pubprop = {
        type_id => $self->find_or_create_cvterm_id(
            cvterm => $cvterm,
            cv     => $attr->cv,
            db     => $attr->db
        ),
        value => $attr->get_value($self),
        rank  => $attr->rank
    };

    $self->add_to_update_pubprops($pubprop);
}

sub update_dicty_pubprops {
    my ( $self, $attr ) = @_;
    for my $value ( @{ $attr->get_value($self) } ) {
        my $pubprops = {
            type_id => $self->find_or_create_cvterm_id(
                cvterm => $value,
                cv     => $attr->cv,
                db     => $attr->db
            ),
            value => 'true',
            rank  => $attr->rank
        };
        $self->add_to_update_pubprops($pubprops);
    }
}

sub update_authors {
    my ( $self, $attr ) = @_;
    for my $author ( @{ $attr->get_value($self) } ) {
        my $author_hash;
        for my $author_attr ( $author->meta->get_all_attributes ) {
            next
                if !$author_attr->does(
                'Modware::Meta::Attribute::Trait::Persistent');
            my $value = $author_attr->get_value($author);
            next if !$value;
            my $column
                = $author_attr->has_column
                ? $author_attr->column
                : $author_attr->name;
            $author_hash->{$column} = $value;
        }
        $self->add_to_update_pubauthors($author_hash);
    }
}

sub update_pub_dbxref {
    my ( $self, $attr, $dbrow ) = @_;
    my $schema = $dbrow->result_source->schema;
    my $value  = $attr->get_value($self);
    my $db     = $attr->has_db ? $attr->db : $attr->name;
    my $db_id  = $self->db_id_by_name($db);
    my $row    = $schema->resultset('General::Dbxref')->search(
        {   accession => $value,
            db_id     => $db_id
        },
        { rows => 1 }
    )->single;

    if ( !$row ) {    #there is nothing to compare so new record
        $self->add_to_update_pub_dbxrefs(
            {   accession => $value,
                db_id     => $db_id
            }
        );
        return;
    }

    ## -- update the existing record
    $self->add_to_update_pub_dbxrefs(
        {   accession => $value,
            dbxref_id => $row->dbxref_id,
            db_id     => $db_id
        }
    );
}

1;    # Magic true value required at end of module

__END__

=head1 NAME

B<Modware::Role::Chado::Reader::BCS::Publication> - [Moose role for persisting publication data to 
chado database]


=head1 VERSION

This document describes <Modware::Role::Chado::Reader::BCS::Publication> version 0.1


=head1 SYNOPSIS

with Modware::Role::Chado::Reader::BCS::Publication;


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



