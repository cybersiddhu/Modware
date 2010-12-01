#!/usr/bin/perl -w

use strict;
use Pod::Usage;
use Getopt::Long;
use YAML qw/LoadFile/;
use Bio::Chado::Schema;
use GOBO::Parsers::OBOParserDispatchHash;
use Data::Dumper::Concise;
use IO::File;
use Carp;
use Try::Tiny;

{

    package Logger;
    use Log::Log4perl;
    use Log::Log4perl::Appender;
    use Log::Log4perl::Level;

    sub handler {
        my ( $class, $file ) = @_;

        my $appender;
        if ($file) {
            $appender = Log::Log4perl::Appender->new(
                'Log::Log4perl::Appender::File',
                filename => $file,
                mode     => 'clobber'
            );
        }
        else {
            $appender
                = Log::Log4perl::Appender->new(
                'Log::Log4perl::Appender::ScreenColoredLevels',
                );
        }

        my $layout = Log::Log4perl::Layout::PatternLayout->new(
            "[%d{MM-dd-yyyy hh:mm}] %p - %m%n");

        my $log = Log::Log4perl->get_logger();
        $appender->layout($layout);
        $log->add_appender($appender);
        $log->level($DEBUG);
        $log;
    }

    package OntoHelper;
    use namespace::autoclean;
    use Moose;
    use MooseX::Params::Validate;
    with 'Modware::Role::Chado::Helper::BCS::Cvterm';

    has 'chado' => (
        is  => 'rw',
        isa => 'Bio::Chado::Schema'
    );

    has 'dbrow' => (
        is      => 'rw',
        isa     => 'HashRef',
        traits  => [qw/Hash/],
        default => sub { {} },
        handles => {
            add_dbrow    => 'set',
            get_dbrow    => 'get',
            delete_dbrow => 'delete',
            has_dbrow    => 'defined'
        }
    );

    sub find_dbxref_id {
        my ( $self, $dbxref, $db ) = validated_list(
            \@_,
            dbxref => { isa => 'Str' },
            db     => { isa => 'Str' },
        );

        my $rs = $self->chado->resultset('General::Dbxref')->search(
            {   accession => $dbxref,
                db_id     => $db
            }
        );
        if ( $rs->count ) {
            return $rs->first->dbxref_id;
        }
    }

    sub find_dbxref_id_by_cvterm {
        my ( $self, $dbxref, $db, $cv, $cvterm ) = validated_list(
            \@_,
            dbxref => { isa => 'Str' },
            db     => { isa => 'Str' },
            cv     => { isa => 'Str' },
            cvterm => { isa => 'Str' },
        );

        my $rs = $self->chado->resultset('General::Dbxref')->search(
            {   'accession'   => $dbxref,
                'db.name'     => $db,
                'cvterm.name' => $cvterm,
                'cv.name'     => $cv
            },
            { join => [ 'db', { 'cvterm' => 'cv' } ] }
        );
        if ( $rs->count ) {
            return $rs->first->dbxref_id;
        }
    }

    sub find_relation_term_id {
        my ( $self, $cvterm, $cv ) = validated_list(
            \@_,
            cvterm => { isa => 'Any' },
            cv     => { isa => 'ArrayRef' }
        );

        ## -- extremely redundant call have to cache later ontology
        my $rs = $self->chado->resultset('Cv::Cvterm')->search(
            {   -and => [
                    -or => [
                        'me.name'          => $cvterm,
                        'dbxref.accession' => $cvterm
                    ],
                    'cv.name' => { -in => $cv }
                ]
            },
            { join => [qw/cv dbxref/] }
        );

        if ( $rs->count ) {
            return $rs->first->cvterm_id;
        }

    }

    sub find_cvterm_id_by_term_id {
        my ( $self, $cvterm, $cv ) = validated_list(
            \@_,
            term_id => { isa => 'Any' },
            cv      => { isa => 'Str' },
        );

        if ( $self->has_idspace($cvterm) ) {
            my ( $db, $id ) = $self->parse_id($cvterm);
            my $rs = $self->chado->resultset('Cv::Cvterm')->search(
                {   'dbxref.accession' => $id,
                    'cv.name'          => $cv,
                    'db.name'          => $db
                },
                { join => [ 'cv', { 'dbxref' => 'db' } ] }
            );

            if ( $rs->count ) {
                return $rs->first->cvterm_id;
            }
        }

        my $rs
            = $self->chado->resultset('Cv::Cvterm')
            ->search( { 'me.name' => $cvterm, 'cv.name' => $cv },
            { join => 'cv' } );

        if ( $rs->count ) {
            return $rs->first->cvterm_id;
        }
    }

    sub find_or_create_db_id {
        my ( $self, $name ) = @_;
        if ( $self->has_dbrow($name) ) {
            return $self->get_dbrow($name)->db_id;
        }
        my $chado = $self->chado;
        my $row   = $chado->txn_do(
            sub {
                $chado->resultset('General::Db')
                    ->find_or_create( { name => $name } );
            }
        );
        $self->add_dbrow( $name, $row );
        $row->db_id;
    }

    sub has_idspace {
        my ( $self, $id ) = @_;
        return 1 if $id =~ /:/;
    }

    sub parse_id {
        my ( $self, $id ) = @_;
        return split /:/, $id;
    }

    __PACKAGE__->meta->make_immutable;

    package OntoManager;
    use namespace::autoclean;
    use Moose;
    use Moose::Util qw/ensure_all_roles/;
    use Carp;
    use Encode;
    use utf8;
    use Data::Dumper::Concise;

    with 'Modware::Role::Chado::Helper::BCS::WithDataStash' =>
        { create_stash_for =>
            [qw/cvterm_dbxrefs cvtermsynonyms cvtermprop_cvterms/] };

    has 'helper' => (
        is      => 'rw',
        isa     => 'OntoHelper',
        trigger => sub {
            my ( $self, $helper ) = @_;
            $self->meta->make_mutable;
            my $engine = 'OntoEngine::'
                . ucfirst lc( $helper->chado->storage->sqlt_type );
            ensure_all_roles( $self, $engine );
            $self->meta->make_immutable;
            $self->setup;
        }
    );

    has 'node' => (
        is        => 'rw',
        isa       => 'GOBO::Node|GOBO::LinkStatement',
        clearer   => 'clear_node',
        predicate => 'has_node'
    );

    has 'graph' => (
        is  => 'rw',
        isa => 'GOBO::Graph'
    );

    has 'cv_namespace' => (
        is  => 'rw',
        isa => 'DBIx::Class::Row',
    );

    has 'db_namespace' => (
        is  => 'rw',
        isa => 'DBIx::Class::Row'
    );

    has 'other_cvs' => (
        is         => 'rw',
        isa        => 'ArrayRef',
        auto_deref => 1,
        default    => sub {
            my ($self) = @_;
            my $names = [
                map { $_->name }
                    $self->helper->chado->resultset('Cv::Cv')->search(
                    {   name => {
                            -not_in =>
                                [ 'relationship', $self->cv_namespace->name ]
                        }
                    }
                    )
            ];
            return $names;
        },
        lazy => 1
    );

    has 'xref_cache' => (
        is      => 'rw',
        isa     => 'HashRef',
        traits  => [qw/Hash/],
        default => sub { {} },
        handles => {
            add_to_xref_cache      => 'set',
            get_from_xref_cache    => 'get',
            clean_xref_cache       => 'clear',
            entries_in_xref_cache  => 'count',
            cached_xref_entries    => 'keys',
            exist_in_xref_cache    => 'defined',
            remove_from_xref_cache => 'delete'
        }
    );

    has 'xref_tracker_cache' => (
        is      => 'rw',
        isa     => 'HashRef',
        traits  => [qw/Hash/],
        default => sub { {} },
        handles => {
            add_to_xref_tracker     => 'set',
            clean_xref_tracker      => 'clear',
            entries_in_xref_tracker => 'count',
            tracked_xref_entries    => 'keys',
            xref_is_tracked         => 'defined',
            remove_xref_tracking    => 'delete'
        }
    );

    has 'cache' => (
        is      => 'rw',
        isa     => 'ArrayRef',
        traits  => [qw/Array/],
        default => sub { [] },
        handles => {
            add_to_cache     => 'push',
            clean_cache      => 'clear',
            entries_in_cache => 'count',
            cache_entries    => 'elements'
        }
    );

    has 'term_cache' => (
        is      => 'rw',
        isa     => 'HashRef',
        traits  => [qw/Hash/],
        default => sub { {} },
        handles => {
            add_to_term_cache   => 'set',
            clean_term_cache    => 'clear',
            terms_in_cache      => 'count',
            terms_from_cache    => 'keys',
            is_term_in_cache    => 'defined',
            get_term_from_cache => 'get'
        }
    );

    has 'skipped_message' => (
        is      => 'rw',
        isa     => 'Str',
        clearer => 'clear_message'
    );

    before [ map { 'handle_' . $_ }
            qw/core alt_ids xrefs synonyms comment rel_prop/ ] => sub {
        my ($self) = @_;
        croak "node is not set\n" if !$self->has_node;
            };

    sub handle_core {
        my ($self) = @_;
        my $node = $self->node;

        #if ( $node->replaced_by ) {
        #    $self->skipped_message(
        #        'Node is replaced by ' . $node->replaced_by );
        #    return;
        #}

        #if ( $node->consider ) {
        #    $self->skipped_message(
        #        'Node has been considered for replacement by '
        #            . $node->consider );
        #    return;
        #}

        my ( $dbxref_id, $db_id, $accession );
        if ( $self->helper->has_idspace( $node->id ) ) {
            my ( $db, $id ) = $self->helper->parse_id( $node->id );
            $db_id     = $self->helper->find_or_create_db_id($db);
            $dbxref_id = $self->helper->find_dbxref_id_by_cvterm(
                dbxref => $id,
                db     => $db,
                cvterm => $node->label,
                cv     => $node->namespace
                ? $node->namespace
                : $self->cv_namespace->name
            );
            $accession = $id;

        }
        else {
            my $namespace
                = $node->namespace
                ? $node->namespace
                : $self->cv_namespace->name;

            $db_id     = $self->helper->find_or_create_db_id($namespace);
            $dbxref_id = $self->helper->find_dbxref_id_by_cvterm(
                dbxref => $node->id,
                db     => $namespace,
                cvterm => $node->label,
                cv     => $namespace
            );
            $accession = $node->id;
        }

        if ($dbxref_id) {    #-- node is already present
            $self->skipped_message(
                "Node is already present with $dbxref_id acc:$accession db: $db_id"
            );
            return;
        }

        $self->add_to_mapper(
            'dbxref' => { accession => $accession, db_id => $db_id } );
        if ( $node->definition ) {
            $self->add_to_mapper( 'definition',
                encode( "UTF-8", $node->definition ) );
        }

        #logic if node has its own namespace defined
        if ( $node->namespace
            and ( $node->namespace ne $self->cv_namespace->name ) )
        {
            if ( $self->helper->exist_cvrow( $node->namespace ) ) {
                $self->add_to_mapper( 'cv_id',
                    $self->helper->get_cvrow( $node->namespace )->cv_id );
            }
            else {
                my $row = $self->helper->chado->txn_do(
                    sub {
                        $self->helper->chado->resultset('Cv::Cv')
                            ->create( { name => $node->namespace } );
                    }
                );
                $self->helper->set_cvrow( $node->namespace, $row );
                $self->add_to_mapper( 'cv_id', $row->cv_id );
            }
        }
        else {
            $self->add_to_mapper( 'cv_id', $self->cv_namespace->cv_id );
        }
        $self->add_to_mapper( 'is_relationshiptype', 1 )
            if ref $node eq 'GOBO::RelationNode';

        if ( $node->obsolete ) {
            $self->add_to_mapper( 'is_obsolete', 1 );
        }
        else {
            $self->add_to_mapper( 'is_obsolete', 0 );
        }

        if ( $node->isa('GOBO::TermNode') ) {
            if ( $self->is_term_in_cache( $node->label ) ) {
                my $term = $self->get_term_from_cache( $node->label );
                if (    ( $term->[0] eq $self->get_map('cv_id') )
                    and ( $term->[1] eq $self->get_map('is_obsolete') ) )
                {
                    $self->skipped_message("Node is already processed");
                    return;
                }
            }
        }

        $self->add_to_mapper( 'name', $node->label );
        $self->add_to_term_cache( $node->label,
            [ $self->get_map('cv_id'), $self->get_map('is_obsolete') ] )
            if $node->isa('GOBO::TermNode');

        return 1;

    }

    sub handle_alt_ids {
        my ($self) = @_;
        my $node = $self->node;
        return if !$node->alt_ids;
        for my $alt_id ( @{ $node->alt_ids } ) {
            if ( $self->helper->has_idspace($alt_id) ) {
                my ( $db, $id ) = $self->helper->parse_id($alt_id);
                $self->add_to_insert_cvterm_dbxrefs(
                    {   dbxref => {
                            accession => $id,
                            db_id => $self->helper->find_or_create_db_id($db)
                        }
                    }
                );

            }
            else {
                $self->add_to_insert_cvterm_dbxrefs(
                    {   dbxref => {
                            accession => $alt_id,
                            db_id     => $self->db_namespace->db_id
                        }
                    }
                );
            }
        }
    }

    sub handle_xrefs {
        my ($self) = @_;
        my $xref_hash = $self->node->xref_h;
        for my $key ( keys %$xref_hash ) {
            my $xref = $xref_hash->{$key};
            my ( $dbxref_id, $db_id, $accession );
            if (    $self->helper->has_idspace( $xref->id )
                and $xref->id !~ /^http/ )
            {
                my ( $db, $id ) = $self->helper->parse_id( $xref->id );
                $db_id = $self->helper->find_or_create_db_id($db);
                if ( !$db or !$id ) {

                    #xref not getting parsed
                    next;
                }
                $accession = $id;
                $dbxref_id = $self->helper->find_dbxref_id(
                    db     => $db_id,
                    dbxref => $id
                );

            }
            else {

                $db_id     = $self->db_namespace->db_id;
                $accession = $xref->id;
                $dbxref_id = $self->helper->find_dbxref_id(
                    db     => $db_id,
                    dbxref => $accession
                );
            }

            if ($dbxref_id) {
                $self->add_to_insert_cvterm_dbxrefs(
                    { dbxref_id => $dbxref_id } );
            }
            elsif ( $self->xref_is_tracked($accession) ) {
                $self->add_to_xref_cache( $accession,
                    [ $self->node->label, $db_id ] );
            }
            else {
                my $insert_hash = {
                    dbxref => { accession => $accession, db_id => $db_id } };

                #if ( $xref->label ) {
                    #$insert_hash->{dbxref}->{description} = $xref->label;
                #}
                $self->add_to_insert_cvterm_dbxrefs($insert_hash);
                $self->add_to_xref_tracker( $accession, 1 );
            }

        }
    }

    sub handle_synonyms {
        my ($self) = @_;
        $self->_handle_synonyms;
    }

    sub handle_comment {
        my ($self) = @_;
        my $node = $self->node;
        return if !$node->comment;
        $self->add_to_insert_cvtermprop_cvterms(
            {   value   => $node->comment,
                type_id => $self->helper->find_or_create_cvterm_id(
                    db     => 'internal',
                    dbxref => 'comment',
                    cvterm => 'comment',
                    cv     => 'cvterm_property_type'
                )
            }
        );
    }

    sub handle_rel_prop {
        my ( $self, $prop, $value ) = @_;
        my $node = $self->node;
        return if !$node->$prop;
        $self->add_to_insert_cvtermprop_cvterms(
            {   value => $value ? $node->$prop : 1,
                type_id => $self->helper->find_or_create_cvterm_id(
                    db     => 'internal',
                    dbxref => $prop,
                    cvterm => $prop,
                    cv     => 'cvterm_property_type'
                )
            }
        );

    }

    sub keep_state_in_cache {
        my ($self) = @_;
        $self->add_to_cache( $self->insert_hashref );
    }

    sub clear_current_state {
        my ($self) = @_;
        $self->clear_stashes;
        $self->clear_node;
    }

    sub handle_relation {
        my ($self)     = @_;
        my $node       = $self->node;
        my $graph      = $self->graph;
        my $type       = $node->relation;
        my $subject    = $node->node;
        my $object     = $node->target;
        my $subj_inst  = $graph->get_node($subject);
        my $obj_inst   = $graph->get_node($object);
        my $default_cv = $self->cv_namespace->name;

        my $type_id = $self->helper->find_relation_term_id(
            cv     => [ $default_cv, 'relationship', $self->other_cvs ],
            cvterm => $type
        );

        if ( !$type_id ) {
            $self->skipped_message("$type relation node not in storage");
            return;
        }

        my $subject_id = $self->helper->find_cvterm_id_by_term_id(
            term_id => $subject,
            cv      => $subj_inst->namespace
        );
        if ( !$subject_id ) {
            $self->skipped_message("subject $subject not in storage");
            return;
        }

        my $object_id = $self->helper->find_cvterm_id_by_term_id(
            term_id => $object,
            cv      => $obj_inst->namespace
        );

        if ( !$object_id ) {
            $self->skipped_message("object $object not in storage");
            return;
        }

        $self->add_to_mapper( 'type_id',    $type_id );
        $self->add_to_mapper( 'subject_id', $subject_id );
        $self->add_to_mapper( 'object_id',  $object_id );
        return 1;
    }

    __PACKAGE__->meta->make_immutable;

    package OntoEngine::Oracle;
    use namespace::autoclean;
    use Bio::Chado::Schema;
    use Moose::Role;

    sub _handle_synonyms {
        my ($self) = @_;
        my $node = $self->node;
        return if !$node->synonyms;
        my %uniq_syns = map { $_->label => $_->scope } @{ $node->synonyms };
        for my $label ( keys %uniq_syns ) {
            $self->add_to_insert_cvtermsynonyms(
                {   'synonym_' => $label,
                    type_id    => $self->helper->find_or_create_cvterm_id(
                        cvterm => $uniq_syns{$label},
                        cv     => 'synonym_type',
                        dbxref => $uniq_syns{$label},
                        db     => 'internal'
                        )

                }
            );
        }
    }

    sub setup {
        my $self       = shift;
        my $source     = $self->helper->chado->source('Cv::Cvtermsynonym');
        my $class_name = 'Bio::Chado::Schema::' . $source->source_name;
        $source->remove_column('synonym');
        $source->add_column(
            'synonym_' => {
                data_type   => 'varchar',
                is_nullable => 0,
                size        => 1024
            }
        );
        $class_name->add_column(
            'synonym_' => {
                data_type   => 'varchar',
                is_nullable => 0,
                size        => 1024
            }
        );
        $class_name->register_column(
            'synonym_' => {
                data_type   => 'varchar',
                is_nullable => 0,
                size        => 1024
            }
        );

    }

    package OntoEngine::Postgresql;
    use namespace::autoclean;
    use Moose::Role;

    sub _handle_synonyms {
        my ($self) = @_;
        my $node = $self->node;
        return if !$node->synonyms;
        my %uniq_syns = map { $_->label => $_->scope } @{ $node->synonyms };
        for my $label ( keys %uniq_syns ) {
            $self->add_to_insert_cvtermsynonyms(
                {   synonym => $label,
                    type_id => $self->helper->find_or_create_cvterm_id(
                        cvterm => $uniq_syns{$label},
                        cv     => 'synonym_type',
                        dbxref => $uniq_syns{$label},
                        db     => 'internal'
                    )
                }
            );
        }
    }

    sub setup {
    }

    package OntoLoader;
    use Moose;
    use Try::Tiny;
    use Carp;
    use Data::Dumper::Concise;
    use namespace::autoclean;

    has 'manager' => (
        is  => 'rw',
        isa => 'OntoManager'
    );

    has 'resultset' => (
        is  => 'rw',
        isa => 'Str'
    );

    sub store_cache {
        my ( $self, $cache ) = @_;
        my $chado = $self->manager->helper->chado;

        my $index;
        try {
            $chado->txn_do(
                sub {

                    #$chado->resultset( $self->resultset )->populate($cache);
                    for my $i ( 0 .. scalar @$cache - 1 ) {
                        $index = $i;
                        $chado->resultset( $self->resultset )
                            ->create( $cache->[$i] );
                    }
                }
            );
        }
        catch {
            warn "error in creating: $_";
            croak Dumper $cache->[$index];
        };
    }

    sub process_xref_cache {
        my ($self) = @_;
        my $cache;
        my $chado = $self->manager->helper->chado;
    ACCESSION:
        for my $acc ( $self->manager->cached_xref_entries ) {
            my $data = $self->manager->get_from_xref_cache($acc);
            my $rs   = $chado->resultset('General::Dbxref')
                ->search( { accession => $acc, db_id => $data->[1] } );
            next ACCESSION if !$rs->count;

            my $cvterm = $chado->resultset('Cv::Cvterm')->find(
                {   name        => $data->[0],
                    is_obsolete => 0,
                    cv_id       => $self->manager->cv_namespace->cv_id
                }
            );
            next ACCESSION if !$cvterm;
            push @$cache,
                {
                cvterm_id => $cvterm->cvterm_id,
                dbxref_id => $rs->first->dbxref_id
                };

            $self->manager->remove_from_xref_cache($acc);
        }

        $chado->txn_do(
            sub {
                $chado->resultset('Cv::CvtermDbxref')->populate($cache);
            }
        ) if defined $cache;
    }

    __PACKAGE__->meta->make_immutable;

}

my ( $dsn, $user, $password, $config, $log_file, $logger );
my $commit_threshold = 1000;
my $attr             = { AutoCommit => 1 };

GetOptions(
    'h|help'                => sub { pod2usage(1); },
    'u|user:s'              => \$user,
    'p|pass|password:s'     => \$password,
    'dsn:s'                 => \$dsn,
    'c|config:s'            => \$config,
    'l|log:s'               => \$log_file,
    'ct|commit_threshold:s' => \$commit_threshold,
    'a|attr:s%{1,}'         => \$attr
);

pod2usage("!! obo input file is not given !!") if !$ARGV[0];

if ($config) {
    my $str = LoadFile($config);
    pod2usage("given config file $config do not have database section")
        if not defined $str->{database};

    pod2usage("given config file $config do not have dsn section")
        if not defined $str->{database}->{dsn};

    $dsn      = $str->{database}->{dsn};
    $user     = $str->{database}->{dsn} || undef;
    $password = $str->{database}->{dsn} || undef;
    $attr     = $str->{database}->{attr} || $attr;
    $logger
        = $str->{log}
        ? Logger->handler( $str->{log} )
        : Logger->handler;

}
else {
    pod2usage("!!! dsn option is missing !!!") if !$dsn;
    $logger = $log_file ? Logger->handler($log_file) : Logger->handler;
}

my $schema = Bio::Chado::Schema->connect( $dsn, $user, $password, $attr );

$logger->info("parsing ontology ....");
my $parser = GOBO::Parsers::OBOParserDispatchHash->new( file => $ARGV[0] );
$parser->parse;
my $graph = $parser->graph;
$logger->info("parsing done ....");

my $default_namespace = $parser->default_namespace;
if ( $schema->resultset('Cv::Cv')->count( { name => $default_namespace } ) ) {
    $logger->error(
        "Given ontology $default_namespace already exist in database");
    $logger->logdie("!!! Could not load a new one !!!!");
}

# - global namespace
my $global_cv = $schema->resultset('Cv::Cv')
    ->find_or_create( { name => $default_namespace } );
my $global_db = $schema->resultset('General::Db')
    ->find_or_create( { name => '_global' } );

my $onto_helper = OntoHelper->new( chado => $schema );
my $onto_manager = OntoManager->new( helper => $onto_helper );
my $loader = OntoLoader->new( manager => $onto_manager );
$loader->resultset('Cv::Cvterm');

$onto_manager->cv_namespace($global_cv);
$onto_manager->db_namespace($global_db);
$onto_manager->graph($graph);

my $rel_term_skipped = 0;
my $rel_term_loaded  = 0;
my $term_skipped     = 0;
my $term_loaded      = 0;
my $rel_loaded       = 0;

#### -- Relations/Typedef -------- ##
my @rel_terms = @{ $graph->relations };
my $rel_count = scalar @rel_terms;
$logger->info("processing $rel_count relationship entries ....");

REL_NODE:
for my $rel (@rel_terms) {
    $onto_manager->node($rel);
    if ( !$onto_manager->handle_core ) {
        $logger->warn( $rel->id, ' ', $rel->label, ' ',
            $onto_manager->skipped_message );
        $onto_manager->clear_message;
        $rel_term_skipped++;
        next REL_NODE;
    }
    my @methods = map { 'handle_' . $_ } qw/synonyms alt_ids xrefs comment/;
    $onto_manager->$_ for @methods;
    $onto_manager->handle_rel_prop($_)
        for (qw/transitive reflexive cyclic anonymous/);
    $onto_manager->handle_rel_prop( $_, 'value' ) for (qw/domain range/);

    $onto_manager->keep_state_in_cache;
    $onto_manager->clear_current_state;

    if ( $onto_manager->entries_in_cache >= $commit_threshold ) {
        my $entries = $onto_manager->entries_in_cache;

        $logger->info("going to load $entries relationships ....");

        #$dumper->print( Dumper $onto_manager->cache );
        $loader->store_cache( $onto_manager->cache );
        $onto_manager->clean_cache;

        $logger->info("loaded $entries relationship nodes  ....");
        $rel_term_loaded += $entries;
    }
}

if ( $onto_manager->entries_in_cache ) {
    my $entries = $onto_manager->entries_in_cache;
    $logger->info("going to load leftover $entries relationship nodes ....");
    $loader->store_cache( $onto_manager->cache );
    $onto_manager->clean_cache;
    $loader->process_xref_cache;

    $logger->info("loaded leftover $entries relationship nodes ....");
    $rel_term_loaded += $entries;
}

$logger->info("Done processing relationship nodes ....");

### ----- Term/Node ----- #####

my $term_count = scalar @{ $graph->terms };
$logger->info("processing $term_count nodes ....");
TERM:
for my $term ( @{ $graph->terms } ) {
    $onto_manager->node($term);
    if ( !$onto_manager->handle_core ) {
        $logger->warn( $term->id, ' ', $term->label, ' ',
            $onto_manager->skipped_message );
        $onto_manager->clear_message;
        $term_skipped++;
        next TERM;
    }
    my @methods = map { 'handle_' . $_ } qw/synonyms alt_ids xrefs comment/;
    $onto_manager->$_ for @methods;
    $onto_manager->keep_state_in_cache;
    $onto_manager->clear_current_state;

    if ( $onto_manager->entries_in_cache >= $commit_threshold ) {
        my $entries = $onto_manager->entries_in_cache;
        $logger->info("going to load $entries terms ....");

        $loader->store_cache( $onto_manager->cache );

        #$dumper->print( Dumper $onto_manager->cache );
        $onto_manager->clean_cache;

        $logger->info("loaded $entries terms ....");
        $term_loaded += $entries;
    }
}

if ( $onto_manager->entries_in_cache ) {
    my $entries = $onto_manager->entries_in_cache;
    $logger->info("going to load leftover $entries terms ....");

    #$dumper->print( Dumper $onto_manager->cache );
    $loader->store_cache( $onto_manager->cache );
    $onto_manager->clean_cache;
    $loader->process_xref_cache;

    $logger->info("loaded $entries terms ....");
    $term_loaded += $entries;

}
$logger->info("Done processing terms ....");

## ----- Relationship/Link Statements -------

my $rel_manager = OntoManager->new( helper => $onto_helper );
my $rel_loader = OntoLoader->new( manager => $rel_manager );
$rel_manager->cv_namespace($global_cv);
$rel_manager->db_namespace($global_db);
$rel_manager->graph($graph);
$rel_loader->resultset('Cv::CvtermRelationship');

my $edges      = $graph->statements;
my $edge_count = scalar @$edges;
$logger->info( $edge_count, " relationships will be loaded" );

RELATION:
for my $link_node (@$edges) {
    $rel_manager->node($link_node);
    if ( !$rel_manager->handle_relation ) {
        $logger->warn( $rel_manager->skipped_message,
            ": ", $link_node->relation, " with ", $link_node->node, " and ",
            $link_node->target );
        $rel_manager->clear_message;
        next RELATION;
    }
    $rel_manager->keep_state_in_cache;
    $rel_manager->clear_current_state;

    if ( $rel_manager->entries_in_cache >= $commit_threshold ) {
        my $entries = $rel_manager->entries_in_cache;
        $logger->info("going to load $entries relationships ....");
        $rel_loader->store_cache( $rel_manager->cache );

        #$dumper->print( Dumper $onto_manager->cache );
        $rel_manager->clean_cache;
        $logger->info("loaded $entries relationships ....");
        $rel_loaded += $entries;
        $logger->info(
            "Going to process ",
            $edge_count - $rel_loaded,
            " relationships ...."
        );
    }
}

if ( $rel_manager->entries_in_cache ) {
    my $entries = $rel_manager->entries_in_cache;
    $logger->info("going to load leftover $entries relationships ....");
    $rel_loader->store_cache( $rel_manager->cache );

    #$dumper->print( Dumper $onto_manager->cache );
    $rel_manager->clean_cache;
    $logger->info("loaded leftover $entries relationships ....");
    $rel_loaded += $entries;
}

$logger->info("Done processing relationships  ....");

$logger->info(
    "Relationship nodes >> Processed:$rel_count Loaded:$rel_term_loaded Skipped:$rel_term_skipped"
);
$logger->info(
    "Terms >> Processed:$term_count Loaded:$term_loaded Skipped:$term_skipped"
);
$logger->info("Relationships >> Processed:$edge_count Loaded:$rel_loaded");

=head1 NAME


B<load_ontology.pl> - [Loads ontology in chado database]


=head1 SYNOPSIS

perl load_ontology [options] <obo file>

perl load_ontology --dsn "dbi:Pg:dbname=gmod" -u tucker -p halo rel.obo

perl load_ontology --dsn "dbi:Oracle:sid=modbase" -u tucker -p halo so.obo

perl drop_ontology --dsn "dbi:Oracle:sid=modbase" -u tucker -p halo -a AutoCommit=1 LongTruncOk=1 go

perl load_ontology -c config.yaml -l output.txt go.obo


=head1 REQUIRED ARGUMENTS

obo_file                 obo format file

=head1 OPTIONS

-h,--help                display this documentation.

--dsn                    dsn of the chado database

-u,--user                chado database user name

-p,--pass,--password     chado database password 

-l,--log                 log file for writing output,  otherwise would go to STDOUT 

-a,--attr                Additonal attribute(s) for database connection passed in key value pair 

-ct,--commit-threshold   No of entries that will be cached before it is commited to
                         storage, default is 1000

-c,--config              yaml config file,  if given would take preference

=head2 Yaml config file format

database:
  dsn:'....'
  user:'...'
  password:'.....'
log: '...'



=head1 DESCRIPTION


=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

Modware

GO::Parsers

=head1 BUGS AND LIMITATIONS

No bugs have been reported.Please report any bugs or feature requests to

B<Siddhartha Basu>


=head1 AUTHOR

I<Siddhartha Basu>  B<siddhartha-basu@northwestern.edu>

=head1 LICENCE AND COPYRIGHT

Copyright (c) B<2010>, Siddhartha Basu C<<siddhartha-basu@northwestern.edu>>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.



