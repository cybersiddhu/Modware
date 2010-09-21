package Test::Chado::Role::Loader::Bcs;

use strict;
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
use MooseX::Aliases;
use MooseX::Params::Validate;
use YAML qw/LoadFile/;
use Bio::Biblio::IO;
use namespace::clean;

# Module implementation
#
requires 'dbh';

has 'schema' => (
    is         => 'rw',
    isa        => 'Bio::Chado::Schema',
    lazy_build => 1,
);

has 'loader_instance' => (
    is      => 'rw',
    isa     => 'Bio::Chado::Schema',
    lazy    => 1,
    builder => '_build_schema'
);

has 'ontology_name' => (
    is  => 'rw',
    isa => 'Str'
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

before 'get_db_id' => sub {
    $_[0]->dbrow if !$_[0]->has_dbrow;
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

has 'ontology_namespace' => (
    is         => 'rw',
    isa        => 'Str',
    lazy_build => 1
);

has 'loader_tag' => (
    is  => 'rw',
    isa => 'Str'
);

has 'cvrow' => (
    is         => 'rw',
    isa        => 'HashRef[Bio::Chado::Schema::Cv::Cv]',
    traits     => ['Hash'],
    lazy_build => 1,
    handles    => {
        get_cvrow => 'get',
        set_cv_id => 'set',
        has_cv_id => 'defined'
    }
);

has 'obo_xml' => (
    is  => 'rw',
    isa => 'Str'
);

has 'cvterm_row' => (
    is        => 'rw',
    isa       => 'HashRef[Bio::Chado::Schema::Cv::Cvterm]',
    traits    => ['Hash'],
    predicate => 'has_cvterm_row',
    default   => sub { {} },
    lazy      => 1,
    handles   => {
        get_cvterm_row   => 'get',
        set_cvterm_row   => 'set',
        exist_cvterm_row => 'defined'
    }
);

sub cvterm_id_by_name {
    my $self = shift;
    my ($name) = pos_validated_list( \@_, { isa => 'Str' } );

    #check if it is already been cached
    if ( $self->exist_cvterm_row($name) ) {
        return $self->get_cvterm_row($name)->cvterm_id;
    }

    #otherwise try to retrieve from database
    my $rs
        = $self->schema->resultset('Cv::Cvterm')->search( { name => $name } );
    if ( $rs->count > 0 ) {
        $self->set_cvterm_row( $name => $rs->first );
        return $rs->first->cvterm_id;
    }

    #otherwise create one using the default cv namespace
    my $row = $self->schema->resultset('Cv::Cvterm')->create_with(
        {   name   => $name,
            cv     => $self->current_cv,
            db     => $self->current_db,
            dbxref => $self->current_cv . ':' . $name
        }
    );
    $self->set_cvterm_row( $name, $row );
    $row->cvterm_id;
}

sub cvterm_ids_by_namespace {
    my $self = shift;
    my ($name) = pos_validated_list( \@_, { isa => 'Str' } );

    if ( $self->exist_cvrow($name) ) {
        my $ids = [ map { $_->cvterm_id } $self->get_cvrow($name)->cvterms ];
        return $ids;
    }

    my $rs = $self->chado->resultset('Cv::Cv')->search( { name => $name } );
    if ( $rs->count > 0 ) {
        my $row = $rs->first;
        $self->set_cvrow( $name, $row );
        my $ids = [ map { $_->cvterm_id } $row->cvterms ];
        return $ids;
    }
    croak "the given cv namespace $name does not exist : create one \n";
}

sub current_cv {
    my ($self) = @_;
    return 'Modware-' . $self->loader_tag . '-' . $self->ontology_namespace;
}

sub current_db {
    my ($self) = @_;
    return
          'GMOD:Modware-'
        . $self->loader_tag . '-'
        . $self->ontology_namespace;
}

sub _build_cvrow {
    my ($self)    = @_;
    my $namespace = $self->ontology_namespace;
    my $name      = 'Modware-' . $self->loader_tag . '-' . $namespace;
    my $cvrow     = $self->schema->resultset('Cv::Cv')
        ->find_or_create( { name => $name } );
    $cvrow->definition('Ontology namespace for modwareX module');
    $cvrow->update;
    return { $namespace => $cvrow, default => $cvrow };
}

sub _build_dbrow {
    my ($self) = @_;
    my $name   = $self->ontology_namespace;
    my $row    = $self->schema->resultset('General::Db')->find_or_create(
        {         name => 'GMOD:Modware-'
                . $self->loader_tag . '-'
                . $self->ontology_namespace,
        }
    );
    $row->description('Test database for module modwareX');
    $row->update;
    return { default => $row, $name => $row };

}

sub default_cv_id {
    $_[0]->get_cv_id('default');
}

sub get_cv_id {
    $_[0]->get_cvrow( $_[1] )->cv_id;
}

sub default_db_id {
    $_[0]->get_db_id('default');

}

sub get_db_id {
    $_[0]->get_dbrow( $_[1] )->db_id;
}

sub lookup_cv_id {
    my ( $self, $namespace ) = @_;
    my $schema = $self->schema;
    if ( $self->has_cv_id($namespace) ) {
        return $self->get_cv_id($namespace);
    }
    my $cvrow;
    try {
        $cvrow = $schema->txn_do(
            sub {
                my $name  = 'Modware-' . $self->loader_tag . '-' . $namespace;
                my $cvrow = $schema->resultset('Cv::Cv')->create(
                    {   name       => $name,
                        definition => "Ontology namespace for modwarex module"
                    }
                );
                $cvrow;
            }
        );
        $schema->txn_commit;
    }
    catch {
        confess "unable to create cv row: $_";
    };
    $self->set_cv_id( $namespace, $cvrow );
    $cvrow->cv_id;
}

sub lookup_db_id {
    my ( $self, $dbname ) = @_;
    my $schema = $self->schema;
    if ( $self->has_db_id($dbname) ) {
        return $self->get_db_id($dbname);
    }
    my $dbrow;
    try {
        $dbrow = $schema->txn_do(
            sub {
                my $name  = $self->current_db . '-' . $dbname;
                my $dbrow = $schema->resultset('General::Db')->create(
                    {   name        => $name,
                        description => "Ontology dbname for modwarex module"
                    }
                );
                $dbrow;
            }
        );
        $schema->txn_commit;
    }
    catch {
        confess "unable to create db row: $_";
    };
    $self->set_db_id( $dbname, $dbrow );
    $dbrow->db_id;
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

sub _build_ontology_namespace {
    my $self   = shift;
    my $method = $self->ontology_name . '_ontology';
    my $namespace;

    #which namespace to use incase it is not present for a particular node
    my $twig = XML::Twig::XPath->new->parsefile( $self->obo_xml );
    my ($node) = $twig->findnodes('/obo/header/default-namespace');
    $namespace = $node->getValue;
    $twig->purge;

    if ( !$namespace ) {
        if ( $self->data_config->$method->has_namespace ) {
            $namespace = $self->data_config->$method->namespace;
        }
    }

    confess "no default namespace being set for this ontology" if !$namespace;
    $namespace;
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

sub reset_all {
    my ($self) = @_;
    $self->clear_graph;
    $self->clear_traverse_graph;
    $self->clear_dbrow;
    $self->clear_cvrow;
    $self->clear_ontology_namespace;
}

sub load_organism {
    my $self = shift;
    my $organism
        = LoadFile( $self->data_config->organism->taxon_file->stringify );
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
            sub {
                $schema->resultset('Organism::Organism')
                    ->search( {},
                    { columns => [ 'organism_id', 'common_name' ] } )
                    ->delete_all;
            }
        );
        $schema->txn_commit;
    }
    catch {
        confess "error in deletion: $_";
    };
}

sub load_pub {
    my ($self) = @_;
    my $name = 'publication';
    $self->ontology_name($name);
    $self->loader_tag($name);
    my $method = $name . '_ontology';
    $self->obo_xml( $self->data_config->pub->journal_file->stringify );
    $self->load_ontology;

}

sub load_rel {
    my ($self) = @_;
    my $name = 'relation';
    $self->ontology_name($name);
    $self->loader_tag($name);
    my $method = $name . '_ontology';
    $self->obo_xml( $self->data_config->cv->relation_file->stringify );
    $self->load_ontology;
}

sub load_so {
    my ($self) = @_;
    my $name = 'sequence';
    $self->ontology_name($name);
    $self->loader_tag($name);
    my $method = $name . '_ontology';
    $self->obo_xml( $self->data_config->cv->sequence_file->stringify );
    $self->load_ontology;

}

sub load_dicty_keywords {
    my ($self) = @_;
    my $name = 'dicty_literature_topic';
    $self->ontology_name($name);
    $self->loader_tag($name);
    my $method = $name . '_ontology';
    $self->obo_xml( $self->data_config->cv->dicty_literature_file->stringify );
    $self->load_ontology;

}

sub load_journal_data {
    my ($self) = @_;
    $self->ontology_namespace('publication');
    my $file = $self->data_config->pub->journal_file;

    my $source = 'Medline';
    my $type   = 'journal_article';

    my $biblio = Bio::Biblio::IO->new(
        -file   => $file,
        -format => 'medlinexml',
        -result => 'medline2ref'
    );

    while ( my $citation = $biblio->next_bibref ) {
        my $count = 1;
        my $authors;
        for my $person ( @{ $citation->authors } ) {
            push @$authors,
                {
                suffix     => $person->suffix,
                surname    => $person->lastname,
                givennames => $person->initials . ' ' . $person->forename,
                rank       => $count++
                };
        }
        $count = 0;

        $self->schema->txn_do(
            sub {
                my $row = $self->schema->resultset('Pub::Pub')->create(
                    {   uniquename => 'PUB' . int( rand(9999999) ),
                        type_id    => $self->cvterm_id_by_name($type),
                        pubplace   => $source,
                        title      => $citation->title,
                        pyear      => $citation->date,
                        pages      => $citation->first_page . '--'
                            . $citation->last_page,
                        series_name => $citation->journal->name,
                        issue       => $citation->issue,
                        volume      => $citation->volume,
                        pubauthors  => $authors,
                        pubprops    => [
                            {   type_id => $self->cvterm_id_by_name('status'),
                                value   => $citation->status,

                            },
                            {   type_id =>
                                    $self->cvterm_id_by_name('abstract'),
                                value => $citation->abstract
                            },
                            {   type_id => $self->cvterm_id_by_name(
                                    'journal_abbreviation'),
                                value => $citation->journal->abbreviation
                            }
                        ]
                    }
                );
                $row->add_to_pub_dbxrefs(
                    {   dbxref => {
                            accession => $citation->journal->issn,
                            db_id     => $self->lookup_db_id('issn')
                        }
                    }
                );
            }
        );
    }

    $file   = $self->data_config->pub->pubmed_file;
    $source = 'Pubmed';
    $type   = 'pubmed_journal_article';

    $biblio = Bio::Biblio::IO->new(
        -file   => $file,
        -format => 'pubmedxml',
    );

    while ( my $citation = $biblio->next_bibref ) {
        my $count = 1;
        my $authors;
        for my $person ( @{ $citation->authors } ) {
            push @$authors,
                {
                suffix     => $person->suffix,
                surname    => $person->lastname,
                givennames => $person->initials . ' ' . $person->forename,
                rank       => $count++
                };
        }
        $count = 0;

        $self->schema->txn_do(
            sub {
                my $row = $self->schema->resultset('Pub::Pub')->create(
                    {   uniquename => $citation->pmid,
                        type_id    => $self->cvterm_id_by_name($type),
                        pubplace   => $source,
                        title      => $citation->title,
                        pyear      => $citation->date,
                        series_name => $citation->journal->name,
                        issue       => $citation->issue,
                        volume      => $citation->volume,
                        pubauthors  => $authors,
                        pubprops    => [
                            {   type_id => $self->cvterm_id_by_name('status'),
                                value   => $citation->status,

                            },
                            {   type_id =>
                                    $self->cvterm_id_by_name('abstract'),
                                value => $citation->abstract
                            },
                            {   type_id => $self->cvterm_id_by_name(
                                    'journal_abbreviation'),
                                value => $citation->journal->abbreviation
                                    || $citation->journal->name
                            }
                        ]
                    }
                );
                $row->add_to_pub_dbxrefs(
                    {   dbxref => {
                            accession => $citation->journal->issn,
                            db_id     => $self->lookup_db_id('issn')
                        }
                    }
                );
            }
        );
    }

    $self->schema->txn_commit;
}

sub load_ontology {
    my ($self) = @_;
    $self->reset_all;
    my $loader = $self->obo_xml_loader;
    $loader->parsefile( $self->obo_xml );
    $loader->purge;
    $self->store_relationship;

}

sub load_fixture {
	my $self = shift;
	$self->load_organism;
	$self->load_rel;
	$self->load_so;
	$self->load_pub;
	$self->load_journal_data;
	$self->load_dicty_keywords;
}

sub unload_pub {
    my ($self) = @_;
    my $name = 'publication';
    $self->ontology_name($name);
    $self->loader_tag($name);
    my $str       = $self->data_config->get_value('ontology');
    my $namespace = $str->{$name}->{namespace};
    $self->unload_ontology($namespace);
}

sub unload_rel {
    my ($self) = @_;
    my $name = 'relation';
    $self->ontology_name($name);
    $self->loader_tag($name);
    my $str       = $self->data_config->get_value('ontology');
    my $namespace = $str->{$name}->{namespace};
    $self->unload_ontology($namespace);
}

sub unload_so {
    my ($self) = @_;
    my $name = 'sequence';
    $self->ontology_name($name);
    $self->loader_tag($name);
    my $str       = $self->data_config->get_value('ontology');
    my $namespace = $str->{$name}->{namespace};
    $self->unload_ontology($namespace);
}

sub unload_dicty_keywords {
    my ($self) = @_;
    my $name = 'dicty_literature_topic';
    $self->ontology_name($name);
    $self->loader_tag($name);
    my $str       = $self->data_config->get_value('ontology');
    my $namespace = $str->{$name}->{namespace};
    $self->unload_ontology($namespace);
}

sub unload_ontology {
    my ($self) = @_;
    my $schema = $self->schema;
    try {
        $schema->txn_do(
            sub {
                my $name = '%Modware-' . $self->loader_tag . '%';
                $schema->resultset('General::Db')
                    ->search( { name => { -like => $name } } )->delete_all;
                $schema->resultset('Cv::Cv')
                    ->search( { name => { -like => $name } } )->delete_all;
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
    my $namespace   = $node->first_child_text('namespace');
    $namespace = $self->ontology_namespace if !$namespace;

    my $def_elem = $node->first_child('def');
    my $definition;
    $definition = $def_elem->first_child_text('defstr') if $def_elem;

    my $schema = $self->schema;
    my $cvterm_row;
    try {
        $cvterm_row = $schema->txn_do(
            sub {
                my $cvterm_row = $schema->resultset('Cv::Cvterm')->create(
                    {   cv_id => $self->lookup_cv_id($namespace),
                        is_relationshiptype => 1,
                        name                => $self->normalize_name($name),
                        definition          => $definition || '',
                        is_obsolete         => $is_obsolete || 0,
                        dbxref              => {
                            db_id     => $self->lookup_db_id($namespace),
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

    $self->create_more_dbxref( $def_elem, $cvterm_row, $namespace );
}

sub load_term {
    my ( $self, $twig, $node ) = @_;

    my $name        = $node->first_child_text('name');
    my $id          = $node->first_child_text('id');
    my $is_obsolete = $node->first_child_text('is_obsolete');
    my $namespace   = $node->first_child_text('namespace');
    $namespace = $self->ontology_namespace if !$namespace;

    my $def_elem = $node->first_child('def');
    my $definition;
    $definition = $def_elem->first_child_text('defstr') if $def_elem;

    my $schema = $self->schema;
    my $cvterm_row;
    try {
        $cvterm_row = $schema->txn_do(
            sub {
                my $cvterm_row = $schema->resultset('Cv::Cvterm')->create(
                    {   cv_id       => $self->lookup_cv_id($namespace),
                        name        => $self->normalize_name($name),
                        definition  => $definition || '',
                        is_obsolete => $is_obsolete || 0,
                        dbxref      => {
                            db_id     => $self->lookup_db_id($namespace),
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

    $self->create_more_dbxref( $def_elem, $cvterm_row, $namespace );
}

sub normalize_name {
    my ( $self, $name ) = @_;
    return $name if $name !~ /:/;
    my $value = ( ( split /:/, $name ) )[1];
    return $value;
}

sub create_more_dbxref {
    my ( $self, $def_elem, $cvterm_row, $namespace ) = @_;
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
                                accession => $alt_id,
                                db_id     => $self->lookup_db_id($namespace)
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
    try {
        $schema->txn_do(
            sub {
                $cvterm_row->create_related(
                    'cvterm_dbxrefs',
                    {   dbxref => {
                            accession => $def_dbx->first_child_text('acc'),
                            db_id     => $self->lookup_db_id($dbname)
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



