package Test::Chado::Role::Loader::BCS;

use version; our $VERSION = qv('0.1');
use warnings;

# Other modules:
use Moose::Role;
use Carp;
use Bio::Chado::Schema;
use Data::Dumper;
use Try::Tiny;
use XML::Twig;
use XML::Twig::XPath;
use Graph;
use Graph::Traversal::BFS;

# Module implementation
#
requires 'dbh';

has 'schema' => (
    is         => 'rw',
    isa        => 'Bio::Chado::Schema',
    lazy_build => 1
);

has 'obo_xml_loader' => (
    is         => 'rw',
    isa        => 'XML::Twig',
    lazy_build => 1
);

has 'graph' => (
    is      => 'rw',
    isa     => 'Graph',
    default => sub { Graph->new( directed => 1 ) },
    lazy    => 1,
    clearer => 'clear_graph'
);

has 'traverse_graph' => (
    is         => 'rw',
    isa        => 'Graph::Traversal',
    lazy_build => 1,
    handles    => { store_relationship => 'bfs' }
);

before 'dbrow' => sub {
    $_[0]->cvrow if !$_[0]->has_cvrow;
};

has 'dbrow' => (
    is         => 'rw',
    isa        => 'HashRef[Bio::Chado::Schema::General::Db]',
    traits     => ['Hash'],
    lazy_build => 1,
    handles    => {
        get_dbrow => 'get',
        set_db_id => 'set',
        has_db_id => 'defined'
    }
);

before 'get_db_id' => sub {
    $_[0]->dbrow if !$_[0]->has_dbrow;
};

has 'namespace' => (
    is      => 'rw',
    isa     => 'Str',
    clearer => 'clear_namespace'
);

has 'cvrow' => (
    is         => 'rw',
    isa        => 'Bio::Chado::Schema::Cv::Cv',
    lazy_build => 1,
    handles    => [qw/cv_id/]
);

has 'obo_xml' => (
    is  => 'rw',
    isa => 'Str'
);

sub default_db_id {
    $_[0]->get_db_id('default');

}

sub get_db_id {
    $_[0]->get_dbrow( $_[1] )->db_id;
}

sub _build_schema {
    my ($self) = @_;
    Bio::Chado::Schema->connect( sub { $self->dbh } );
}

sub _build_obo_xml_loader {
    my ($self) = @_;
    XML::Twig->new(
        twig_handlers => {
            term    => sub { $self->load_term(@_) },
            typedef => sub { $self->load_typedef(@_) }
        }
    );
}

sub _build_cvrow {
    my $self      = shift;
    my $twig      = XML::Twig::XPath->new->parsefile( $self->obo_xml );
    my ($node)    = $twig->findnodes('/obo/header/default-namespace');
    my $namespace = $node->getValue;
    $self->namespace($namespace);

    my $cvrow = $self->schema->resultset('Cv::Cv')->find_or_create(
        {   name       => "ModwareX-$namespace",
            definition => 'Ontology namespace for modwareX module'
        }
    );
    $twig->purge;
    $cvrow;
}

sub _build_traverse_graph {
    my ($self) = @_;
    Graph::Traversal::BFS->new(
        $self->graph,
        pre_edge => sub {
            $self->handle_relationship(@_);
        },
        back_edge => sub {
            $self->handle_relationship(@_);
        },
        down_edge => sub {
            $self->handle_relationship(@_);
        },
        non_tree_edge => sub {
            $self->handle_relationship(@_);
        },
    );
}

sub _build_dbrow {
    my ($self) = @_;
    my $row = $self->schema->resultset('General::Db')->find_or_create(
        {   name        => 'GMOD:ModwareX-' . $self->namespace,
            description => 'Test database for module modwareX'
        }
    );
    return { default => $row };

}

sub reset_all {
    my ($self) = @_;
    $self->clear_graph;
    $self->clear_traverse_graph;
    $self->clear_dbrow;
    $self->clear_cvrow;
    $self->clear_namespace;
}

sub load_organism {
    my $self     = shift;
    my $organism = $self->fixture->organism;
    unshift @$organism, [qw/abbreviation genus species common_name/];

    my $schema = $self->schema;
    try {
        $schema->txn_do(
            sub {
                $schema->populate( 'Organism::Organism', $organism );
            }
        );
        $schema->txn_commit;
    }
    catch {
        confess "error: $_";
    };
}

sub unload_organism {
    my ($self) = @_;
    my $schema = $self->schema;
    try {
        $schema->txn_do(
            sub { $schema->resultset('Organism::Organism')->delete_all; } );
        $schema->txn_commit;
    }
    catch {
        confess "error in deletion: $_";
    };
}

sub load_rel {
    my ($self) = @_;
    $self->obo_xml( $self->fixture->rel_ontology );
    $self->load_ontology;
}

sub load_so {
    my ($self) = @_;
    $self->obo_xml( $self->fixture->seq_ontology );
    $self->load_ontology;
}

sub load_ontology {
    my ($self) = @_;
    $self->reset_all;
    my $loader = $self->obo_xml_loader;
    $loader->parsefile( $self->obo_xml );
    $loader->purge;
    $self->store_relationship;

}

sub unload_rel {
    my ($self) = @_;
    $self->unload_ontology('relationship');
}

sub unload_so {
    my ($self) = @_;
    $self->unload_ontology('sequence');
}

sub unload_ontology {
	my ($self,  $namespace) = @_;	
    my $schema = $self->schema;
    try {
        $schema->txn_do(
            sub {
                $schema->resultset('General::Db')
                    ->search(
                    { name => { -like => '%ModwareX-'.$namespace } } )
                    ->delete_all;
                $schema->resultset('Cv::Cv')
                    ->search(
                    { name => { -like => '%ModwareX-'.$namespace } } )
                    ->delete_all;
            }
        );
        $schema->txn_commit;
    }
    catch {
        confess "error in deleting: $_";
    }
}

sub handle_relationship {
    my ( $self, $parent, $child, $traverse ) = @_;
    my ( $relation_id, $parent_id, $child_id );

    # -- relation/edge
    if ( $self->graph->has_edge_attribute( $parent, $child, 'id' ) ) {
        $relation_id
            = $self->graph->get_edge_attribute( $parent, $child, 'id' );
    }
    else {

        # -- get the id from the storage
        $relation_id = $self->name2id(
            $self->graph->get_edge_attribute(
                $parent, $child, 'relationship'
            ),
        );
        $self->graph->set_edge_attribute( $parent, $child, 'id',
            $relation_id );
    }

    # -- parent
    if ( $self->graph->has_vertex_attribute( $parent, 'id' ) ) {
        $parent_id = $self->graph->get_vertex_attribute( $parent, 'id' );
    }
    else {
        $parent_id = $self->name2id($parent);
        $self->graph->set_vertex_attribute( $parent, 'id', $parent_id );
    }

    # -- child
    if ( $self->graph->has_vertex_attribute( $child, 'id' ) ) {
        $child_id = $self->graph->get_vertex_attribute( $child, 'id' );
    }
    else {
        $child_id = $self->name2id($child);
        $self->graph->set_vertex_attribute( $child, 'id', $child_id );
    }

    my $schema = $self->schema;
    try {
        $schema->txn_do(
            sub {
                $schema->resultset('Cv::CvtermRelationship')->create(
                    {   object_id  => $parent_id,
                        subject_id => $child_id,
                        type_id    => $relation_id
                    }
                );
            }
        );
        $schema->txn_commit;
    }
    catch { confess "error in inserting: $_" };
}

sub name2id {
    my ( $self, $name ) = @_;
    my $row = $self->schema->resultset('Cv::Cvterm')
        ->search( { 'name' => $name, }, { rows => 1 } )->single;

    if ( !$row ) {    #try again in dbxref
        $row
            = $self->schema->resultset('General::Dbxref')
            ->search( { accession => { -like => '%' . $name } },
            { rows => 1 } )->single;
        if ( !$row ) {
            $self->alert("serious problem: **$name** nowhere to be found");
            return;
        }
        return $row->cvterm->cvterm_id;
    }
    $row->cvterm_id;
}

sub build_relationship {
    my ( $self, $node, $cvterm_row ) = @_;
    my $child = $cvterm_row->name;
    for my $elem ( $node->children('is_a') ) {
        my $parent = $self->normalize_name( $elem->text );
        $self->graph->set_edge_attribute( $parent, $child, 'relationship',
            'is_a' );
    }

    for my $elem ( $node->children('relationship') ) {
        my $parent = $self->normalize_name( $elem->first_child_text('to') );
        $self->graph->add_edge( $parent, $child );
        $self->graph->set_edge_attribute( $parent, $child, 'relationship',
            $self->normalize_name( $elem->first_child_text('type') ) );
    }
}

sub load_typedef {
    my ( $self, $twig, $node ) = @_;

    my $name        = $node->first_child_text('name');
    my $id          = $node->first_child_text('id');
    my $is_obsolete = $node->first_child_text('is_obsolete');

    my $def_elem = $node->first_child('def');
    my $definition = $def_elem->first_child_text('defstr') if $def_elem;

    my $schema = $self->schema;
    my $cvterm_row;
    try {
        $cvterm_row = $schema->txn_do(
            sub {
                my $cvterm_row = $schema->resultset('Cv::Cvterm')->create(
                    {   cv_id               => $self->cv_id,
                        is_relationshiptype => 1,
                        name                => $self->normalize_name($name),
                        definition          => $definition || '',
                        is_obsolete         => $is_obsolete || 0,
                        dbxref              => {
                            db_id     => $self->default_db_id,
                            accession => $id,
                        }
                    }
                );
                $cvterm_row;
            }
        );
        $schema->txn_commit;
    }
    catch {
        confess "Error in inserting cvterm $_\n";
    };

    #hold on to the relationships between nodes
    $self->build_relationship( $node, $cvterm_row );

    #no additional dbxref
    return if !$def_elem;

    $self->create_more_dbxref( $def_elem, $cvterm_row );
}

sub load_term {
    my ( $self, $twig, $node ) = @_;

    my $name        = $node->first_child_text('name');
    my $id          = $node->first_child_text('id');
    my $is_obsolete = $node->first_child_text('is_obsolete');

    my $def_elem = $node->first_child('def');
    my $definition = $def_elem->first_child_text('defstr') if $def_elem;

    my $schema = $self->schema;
    my $cvterm_row;
    try {
        $cvterm_row = $schema->txn_do(
            sub {
                my $cvterm_row = $schema->resultset('Cv::Cvterm')->create(
                    {   cv_id       => $self->cv_id,
                        name        => $self->normalize_name($name),
                        definition  => $definition || '',
                        is_obsolete => $is_obsolete || 0,
                        dbxref      => {
                            db_id     => $self->default_db_id,
                            accession => $id,
                        }
                    }
                );
                $cvterm_row;
            }
        );
        $schema->txn_commit;
    }
    catch {
        confess "Error in inserting cvterm $_\n";
    };

    #hold on to the relationships between nodes
    $self->build_relationship( $node, $cvterm_row );

    #no additional dbxref
    return if !$def_elem;

    $self->create_more_dbxref( $def_elem, $cvterm_row );
}

sub normalize_name {
    my ( $self, $name ) = @_;
    return $name if $name !~ /:/;
    my $value = ( ( split /:/, $name ) )[1];
    return $value;
}

sub create_more_dbxref {
    my ( $self, $def_elem, $cvterm_row ) = @_;
    my $schema = $self->schema;

    # - first one goes with alternate id
    my $alt_id = $def_elem->first_child_text('alt_id');
    if ($alt_id) {
        try {
            $schema->txn_do(
                sub {
                    $cvterm_row->create_related(
                        'cvterm_dbxrefs',
                        {   dbxref => {
                                accession => db_id => $self->default_db_id
                            }
                        }
                    );
                }
            );
            $schema->txn_commit;
        }
        catch {
            confess "error in creating dbxref $_";
        };
    }

    #no more additional dbxrefs
    my $def_dbx = $def_elem->first_child('dbxref');
    return if !$def_dbx;

    my $dbname = $def_dbx->first_child_text('dbname');
    my $extra_db_id;
    if ( $self->has_db_id($dbname) ) {
        $extra_db_id = $self->get_db_id($dbname);
    }
    else {
        my $extra_db_row = $schema->resultset('General::Db')->find_or_create(
            {   name => $def_dbx->first_child_text('dbname')
                    . ':ModwareX-'
                    . $self->namespace,
                description => 'Extra test database for module modwarex'
            }
        );
        $self->set_db_id( $dbname, $extra_db_row );
        $extra_db_id = $extra_db_row->db_id;
    }

    try {
        $schema->txn_do(
            sub {
                $cvterm_row->create_related(
                    'cvterm_dbxrefs',
                    {   dbxref => {
                            accession => $def_dbx->first_child_text('acc'),
                            db_id     => $extra_db_id
                        }
                    }
                );
            }
        );
        $schema->txn_commit;
    }
    catch { confess "error in creating dbxref $_" };
}

1;    # Magic true value required at end of module

__END__

=head1 NAME

<MODULE NAME> - [One line description of module's purpose here]


=head1 VERSION

This document describes <MODULE NAME> version 0.0.1


=head1 SYNOPSIS

use <MODULE NAME>;

=for author to fill in:
Brief code example(s) here showing commonest usage(s).
This section will be as far as many users bother reading
so make it as educational and exeplary as possible.


=head1 DESCRIPTION

=for author to fill in:
Write a full description of the module and its features here.
Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=for author to fill in:
Write a separate section listing the public components of the modules
interface. These normally consist of either subroutines that may be
exported, or methods that may be called on objects belonging to the
classes provided by the module.

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

<MODULE NAME> requires no configuration files or environment variables.


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


