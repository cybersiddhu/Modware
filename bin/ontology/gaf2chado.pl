#!/usr/bin/perl -w

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

1;

package GAFHelper;
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

sub has_idspace {
    my ( $self, $id ) = @_;
    return 1 if $id =~ /:/;
}

sub parse_id {
    my ( $self, $id ) = @_;
    return split /:/, $id;
}

sub parse_evcode {
    my $self = shift;
    my ($anno) = pos_validated_list( \@_, { isa => 'GOBO::Annotation' } );
    my ($evcode) = ( ( split /\-/, $anno->evidence ) )[0];
    $evcode;
}

sub has_with_field {
    my $self = shift;
    my ($anno) = pos_validated_list( \@_, { isa => 'GOBO::Annotation' } );
    my ($with_field) = ( ( split /\-/, $anno->evidence ) )[1];
    return $with_field if $with_field;
}

sub parse_with_field {
    my ( $self, $string ) = @_;
    if ( $string =~ /\|/ ) {
        my @with = split /\|/, $string;
        return \@with;
    }
    return [$string];
}

sub is_from_pubmed {
    my ( $self, $id ) = @_;
    return $id if $id =~ /^PMID/;
}

sub get_anno_ref_records {
    my ( $self, $anno ) = @_;
    my @ids;
    for my $xref ( @{ $anno->provenance->xrefs } ) {
        my ( $db, $id ) = $self->parse_id( $xref->id );
        push @ids, $id;
    }
    return @ids;

}

sub get_db_pub_records {
    my ( $self, $row ) = @_;
    my $fcp_rs = $row->feature_cvterm_pubs;
    if ( $fcp_rs->count ) {
        my @ids = map { $_->pub->uniquename } $fcp_rs->all;
        return @ids;
    }
}

sub get_db_records {
    my ( $self, $row ) = @_;
    my $fcd_rs = $row->feature_cvterm_dbxrefs();
    if ( $fcd_rs->count and $fcd_rs->count > 1 ) {
        my @ids = map { $_->dbxref->accession } $fcd_rs->all;
        return @ids;
    }
}

__PACKAGE__->meta->make_immutable;

1;

package GAFManager;
use namespace::autoclean;
use Moose;
use Carp;
use Digest;
use Data::Dumper::Concise;
use Moose::Util qw/ensure_all_roles/;
with 'Modware::Role::Chado::Helper::BCS::WithDataStash' =>
    { create_stash_for =>
        [qw/feature_cvterm_dbxrefs feature_cvtermprops feature_cvterm_pubs/]
    };

has 'helper' => (
    is      => 'rw',
    isa     => 'GAFHelper',
    trigger => sub {
        my ( $self, $helper ) = @_;
        my $chado = $helper->chado;
        $self->meta->make_mutable;
        my $engine = 'GAFEngine::' . ucfirst lc( $chado->storage->sqlt_type );
        ensure_all_roles( $self, $engine );
        $self->meta->make_immutable;
        $self->setup;
        $self->meta->make_immutable;
        $self->_preload_evcode_cache;
        $self->add_new_relation;
    },
    handles => {
        'is_from_pubmed'           => 'is_from_pubmed',
        'has_idspace'              => 'has_idspace',
        'chado'                    => 'chado',
        'parse_id'                 => 'parse_id',
        'get_anno_ref_records'     => 'get_anno_ref_records',
        'get_db_records'           => 'get_db_records',
        'get_db_pub_records'       => 'get_db_pub_records',
        'parse_evcode'             => 'parse_evcode',
        'find_or_create_cvterm_id' => 'find_or_create_cvterm_id',
        'has_with_field'           => 'has_with_field',
        'parse_with_field'         => 'parse_with_field'
    }
);

has 'extra_cv' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'gene_ontology_association'
);

has 'extra_db' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'GO'
);

has 'date_column' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'date'
);

has 'source_column' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'source'
);

has 'with_column' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'with'
);

has 'qualifier_column' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'qualifier'
);

has 'target' => (
    is        => 'rw',
    isa       => 'GOBO::Node',
    clearer   => 'clear_target',
    predicate => 'has_target'
);

has 'feature' => (
    is        => 'rw',
    isa       => 'GOBO::Node',
    clearer   => 'clear_feature',
    predicate => 'has_feature'
);

has 'annotation' => (
    is        => 'rw',
    isa       => 'GOBO::Annotation',
    clearer   => 'clear_annotation',
    predicate => 'has_annotation'
);

has 'feature_row' => (
    is        => 'rw',
    isa       => 'Bio::Chado::Schema::Sequence::Feature',
    predicate => 'has_feature_row',
    clearer   => 'clear_feature_row'
);

has 'cvterm_row' => (
    is        => 'rw',
    isa       => 'Bio::Chado::Schema::Cv::Cvterm',
    clearer   => 'clear_cvterm_row',
    predicate => 'has_cvterm_row'
);

has 'graph' => (
    is  => 'rw',
    isa => 'GOBO::Graph'
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

has 'evcode_cache' => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [qw/Hash/],
    default => sub { {} },
    handles => {
        add_to_evcode_cache   => 'set',
        clean_evcode_cache    => 'clear',
        evcodes_in_cache      => 'count',
        evcodes_from_cache    => 'keys',
        has_evcode_in_cache   => 'defined',
        get_evcode_from_cache => 'get'
    }
);

has '_rev_evcode_cache' => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [qw/Hash/],
    default => sub { {} },
    handles => {
        '_rev_add_to_evcode_cache'   => 'set',
        '_clean_rev_evcode_cache'    => 'clear',
        '_has_rev_evcode_in_cache'   => 'defined',
        '_get_rev_evcode_from_cache' => 'get'
    }
);

has 'digest_cache' => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [qw/Hash/],
    default => sub { {} },
    handles => {
        set_rank_in_digest_cache => 'set',
        clean_digest_cache       => 'clear',
        has_digest_in_cache      => 'defined',
        rank_from_digest_cache   => 'get'
    }
);

has 'skipped_message' => (
    is      => 'rw',
    isa     => 'Str',
    clearer => 'clear_message'
);

has 'update_message' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    traits  => [qw/Array/],
    default => sub { [] },
    handles => {
        add_to_update_message    => 'push',
        get_all_update_message   => 'elements',
        clear_all_update_message => 'clear'
    }
);

sub get_db_qual {
    my $self = shift;
    my $row  = shift;
    my $rs
        = $row->feature_cvtermprops(
        { 'type.name' => $self->qualifier_column },
        { join        => 'type' } );
    if ( $rs->count ) {
        return [ map { $_->value } $rs->all ];
    }
}

sub add_new_relation {
    my ($self) = @_;
    my $schema = $self->chado;
    $schema->source('Sequence::Feature')->add_relationship(
        'dbxref_inner',
        'Bio::Chado::Schema::General::Dbxref',
        { 'foreign.dbxref_id' => 'self.dbxref_id' },
        { join_type           => 'INNER' }
    );

}

sub find_annotated {
    my ($self) = @_;
    my $anno = $self->annotation;

    # In case of GAF2 try to look for entry in column 17
    my $feature
        = $anno->specific_node
        ? $anno->specific_node
        : $anno->gene;
    $self->feature($feature);

    my $id = $feature->id;
    if ( $self->has_idspace($id) ) {
        my @data = $self->parse_id($id);
        $id = $data[1];
    }
    my $rs
        = $self->chado->resultset('Sequence::Feature')
        ->search(
        { -or => [ 'uniquename' => $id, 'dbxref_inner.accession' => $id ] },
        { join => 'dbxref_inner', cache => 1 } );

    if ( !$rs->count ) {
        $self->skipped_message(
            'DB object id ' . $feature->id . ' not found' );
        return;
    }
    if ( $rs->count > 1 ) {
        $self->skipped_message(
            'Multiple object ids ',
            join( ' - ', map { $_->uniquename } $rs->all ),
            ' is mapped to ',
            $feature->id
        );
        return;
    }
    $self->feature_row( $rs->first );
    $rs->first->feature_id;
}

sub find_term {
    my ($self) = @_;
    my $anno   = $self->annotation;
    my $target = $anno->target;
    $self->target($target);

    my ( $db, $id ) = $self->parse_id( $target->id );
    my $rs = $self->chado->resultset('Cv::Cvterm')->search(
        {   'db.name'          => $db,
            'dbxref.accession' => $id,
            'cv.name'          => $target->namespace
        },
        { join => [ 'cv', { 'dbxref' => 'db' } ] }
    );

    if ( !$rs->count ) {
        $self->skipped_message("GO id $id not found");
        return;
    }

    if ( $rs->count > 1 ) {
        $self->skipped_message(
            'Multiple GO ids ',
            join( ' - ', map { $_->dbxref->accession } $rs->all ),
            ' is mapped to ', $id
        );
        return;
    }
    $self->cvterm_row( $rs->first );
    $rs->first->cvterm_id;

}

sub check_for_evcode {
    my ( $self, $anno ) = @_;
    $anno ||= $self->annotation;
    my $evcode = $self->parse_evcode($anno);
    return $self->get_evcode_from_cache($evcode)
        if $self->has_evcode_in_cache($evcode);
    $self->skipped_message("$evcode not found");
    return 0;
}

sub find_annotation {
    my ($self)      = @_;
    my $anno        = $self->annotation;
    my $feature_row = $self->feature_row;
    my $target_row  = $self->cvterm_row;
    my $evcode      = $self->parse_evcode($anno);
    my $evcode_id = $self->get_evcode_from_cache($evcode)->cvterm->cvterm_id;

    my $rs = $self->chado->resultset('Sequence::FeatureCvterm')->search(
        {   feature_id => $feature_row->feature_id,
            cvterm_id  => $target_row->cvterm_id,
        },
    );

    my ( $db, $id ) = $self->parse_id( $anno->provenance->id );
    if ( $rs->count ) {
        while ( my $row = $rs->next ) {
            ## -- same evcode
            ## 1. Identical pubmed id: Record need update
            ## 2. Different pubmed id: New record
            ## -- We don't need to check the graph because four parameters(goid, geneid,  evcode,
            ## -- referernce) with identical value in the same GAF file signify identical record
            ## -- which violates the GAF rules anyway. It might happen only when existing GAF
            ## -- records are being updated.
            my $evrow
                = $row->feature_cvtermprops(
                { 'cv.name' => { -like  => 'evidence_code%' } },
                { join      => { 'type' => 'cv' } } )->first;

            if ( $evrow->type->cvterm_id == $evcode_id ) {
                return GAFRank->new( row => $row )
                    if $row->pub->uniquename eq $id;
            }
        }
    }

    ## -- should be a new record however we have determine if it need to be stored with
    ## -- new rank
    ## -- Different evcode
    ## -- make a sha1 digest of three parameters
    my $str    = $anno->target->id . $anno->gene->id . $id;
    my $digest = Digest->new('SHA-1')->add($str)->digest;
    if ( $self->has_digest_in_cache($digest) ) {
        ## exist so its a new record with a new rank
        my $rank = $self->rank_from_digest_cache($digest);
        $self->set_rank_in_digest_cache( $digest, $rank + 1 );
        return GAFRank->new( rank => $rank + 1 );
    }
    ## new record with default rank
    $self->set_rank_in_digest_cache( $digest, 0 );
    return;

}

sub find_dicty_annotation {
    my ($self)      = @_;
    my $anno        = $self->annotation;
    my $feature_row = $self->feature_row;
    my $target_row  = $self->cvterm_row;
    my $evcode      = $self->parse_evcode($anno);
    my $evcode_id = $self->get_evcode_from_cache($evcode)->cvterm->cvterm_id;

    my $rs = $self->chado->resultset('Sequence::FeatureCvterm')->search(
        {   feature_id => $feature_row->feature_id,
            cvterm_id  => $target_row->cvterm_id,
        },
    );

    my ( $db, $id ) = $self->parse_id( $anno->provenance->id );
    if ( $rs->count ) {
        while ( my $row = $rs->next ) {
            ## -- same evcode
            ## 1. Identical pubmed id: Record need update
            ## 2. Different pubmed id: New record
            ## -- We don't need to check the graph because four parameters(goid, geneid,  evcode,
            ## -- referernce) with identical value in the same GAF file signify identical record
            ## -- which violates the GAF rules anyway. It might happen only when existing GAF
            ## -- records are being updated.
            my $evrow
                = $row->feature_cvtermprops(
                { 'cv.name' => { -like  => 'evidence_code%' } },
                { join      => { 'type' => 'cv' } } )->first;

            if ( $evrow->type->cvterm_id == $evcode_id ) {
                return GAFRank->new( row => $row )
                    if $id eq $row->pub->pub_id;
            }
        }
    }

    ## -- should be a new record however we have determine if it need to be stored with
    ## -- new rank
    ## -- Different evcode
    ## -- make a sha1 digest of three parameters
    my $str    = $anno->target->id . $anno->gene->id . $id;
    my $digest = Digest->new('SHA-1')->add($str)->digest;
    if ( $self->has_digest_in_cache($digest) ) {
        ## exist so its a new record with a new rank
        my $rank = $self->rank_from_digest_cache($digest);
        $self->set_rank_in_digest_cache( $digest, $rank + 1 );
        return GAFRank->new( rank => $rank + 1 );
    }
    ## new record with default rank
    $self->set_rank_in_digest_cache( $digest, 0 );
    return;

}

sub keep_state_in_cache {
    my ($self) = @_;
    $self->add_to_cache( $self->insert_hashref );
}

sub clear_current_state {
    my ($self) = @_;
    $self->clear_stashes;
    $self->clear_target;
    $self->clear_feature;
    $self->clear_annotation;
    $self->clear_feature_row;
    $self->clear_cvterm_row;
}

sub process_annotation_with_rank {
    my ( $self, $rank ) = @_;
    $self->add_to_mapper( 'rank', $rank );
    return $self->process_annotation;
}

sub process_dicty_annotation_with_rank {
    my ( $self, $rank ) = @_;
    $self->add_to_mapper( 'rank', $rank );
    return $self->process_dicty_annotation;
}

sub process_annotation {
    my ($self) = @_;
    my $anno = $self->annotation;

    $self->add_to_mapper( 'feature_id', $self->feature_row->feature_id );
    $self->add_to_mapper( 'cvterm_id',  $self->cvterm_row->cvterm_id );
    $self->add_to_mapper( 'is_not',     1 ) if $anno->negated;

    my $reference = $anno->provenance->id;
    my ( $db, $ref_id ) = $self->parse_id($reference);
    my $pub_row = $self->chado->resultset('Pub::Pub')
        ->find( { uniquename => $ref_id } );
    if ( !$pub_row ) {
        $self->skipped_message("$reference Not found");
        return;
    }
    $self->add_to_mapper( 'pub_id', $pub_row->pub_id );

    ## -- Rest of the dbxrefs if any
XREF:
    for my $xref ( @{ $anno->provenance->xrefs } ) {
        my ( $db, $ref_id ) = $self->parse_id( $xref->id );
        my $pub_row = $self->chado->resultset('Pub::Pub')
            ->find( { uniquename => $ref_id } );
        if ($pub_row) {
            $self->insert_to_feature_cvterm_pubs(
                { 'pub_id' => $pub_row->pub_id } );
        }
        else {
            my $dbxref_rs = $self->chado->resultset('General::Dbxref')
                ->search( { accession => $ref_id } );
            if ( !$dbxref_rs->count ) {
                warn $xref->id, " Not found\n";
                next XREF;
            }
            elsif ( $dbxref_rs->count > 1 ) {
                warn $xref->id, " multiple map found\n";
                next XREF;
            }
            else {
                $self->add_to_insert_feature_cvterm_dbxrefs(
                    { dbxref_id => $dbxref_rs->first->dbxref_id } );
            }
        }
    }

    if ( my $evcode_rs = $self->check_for_evcode($anno) ) {
        $self->add_to_insert_feature_cvtermprops(
            {   type_id => $evcode_rs->cvterm_id,
                value   => 1
            }
        );
    }
    else {
        $self->skip_message( $anno->evidence, ' not found' );
        return;
    }

    ## -- date column 14
    $self->add_to_insert_feature_cvtermprops(
        {   type_id => $self->find_or_create_cvterm_id(
                cv     => $self->extra_cv,
                cvterm => $self->date_column,
                dbxref => $self->date_column,
                db     => $self->extra_db
            ),
            value => $anno->date_compact
        }
    );

    ## -- source column 15
    $self->add_to_insert_feature_cvtermprops(
        {   type_id => $self->find_or_create_cvterm_id(
                cv     => $self->extra_cv,
                cvterm => $self->source_column,
                dbxref => $self->source_column,
                db     => $self->extra_db
            ),
            value => $anno->source->id
        }
    );

    ## -- with column 8
    if ( my $with_field = $self->has_with_field($anno) ) {
        my $values = $self->parse_with_field($with_field);
        for my $i ( 0 .. scalar @$values - 1 ) {
            $self->add_to_insert_feature_cvtermprops(
                {   type_id => $self->find_or_create_cvterm_id(
                        cv     => $self->extra_cv,
                        cvterm => $self->with_column,
                        dbxref => $self->with_column,
                        db     => $self->extra_db
                    ),
                    value => $values->[$i],
                    rank  => $i
                }
            );
        }
    }

    ## -- extra qualifiers
    my $qual = [ grep { $_->id ne 'not' } $anno->qualifier_list ];
    if ( defined $qual ) {
        for my $entry (@$qual) {
            $self->add_to_insert_feature_cvtermprops(
                {   type_id => $self->find_or_create_cvterm_id(
                        cv     => $self->extra_cv,
                        cvterm => $self->qualifier_column,
                        dbxref => $self->qualifier_column,
                        db     => $self->extra_db
                    ),
                    value => $entry->id,
                }
            );
        }

    }

    return 1;
}

sub process_dicty_annotation {
    my ($self) = @_;
    my $anno = $self->annotation;

    $self->add_to_mapper( 'feature_id', $self->feature_row->feature_id );
    $self->add_to_mapper( 'cvterm_id',  $self->cvterm_row->cvterm_id );
    $self->add_to_mapper( 'is_not',     1 ) if $anno->negated;

    my $reference = $anno->provenance->id;
    my ( $db, $ref_id ) = $self->parse_id($reference);
    my $pub_row
        = $self->chado->resultset('Pub::Pub')->find( { pub_id => $ref_id } );
    if ( !$pub_row ) {
        $self->skipped_message("$reference Not found");
        return;
    }
    $self->add_to_mapper( 'pub_id', $pub_row->pub_id );

    ## -- Rest of the dbxrefs if any
XREF:
    for my $xref ( @{ $anno->provenance->xrefs } ) {
        my ( $db, $ref_id ) = $self->parse_id( $xref->id );
        my $pub_row = $self->chado->resultset('Pub::Pub')
            ->find( { pub_id => $ref_id } );
        if ($pub_row) {
            $self->insert_to_feature_cvterm_pubs(
                { 'pub_id' => $pub_row->pub_id } );
        }
        else {
            my $dbxref_rs = $self->chado->resultset('General::Dbxref')
                ->search( { accession => $ref_id } );
            if ( !$dbxref_rs->count ) {
                warn $xref->id, " Not found\n";
                next XREF;
            }
            elsif ( $dbxref_rs->count > 1 ) {
                warn $xref->id, " multiple map found\n";
                next XREF;
            }
            else {
                $self->add_to_insert_feature_cvterm_dbxrefs(
                    { dbxref_id => $dbxref_rs->first->dbxref_id } );
            }
        }
    }

    if ( my $evcode_rs = $self->check_for_evcode($anno) ) {
        $self->add_to_insert_feature_cvtermprops(
            {   type_id => $evcode_rs->cvterm_id,
                value   => 1
            }
        );
    }
    else {
        $self->skip_message( $anno->evidence, ' not found' );
        return;
    }

    ## -- date column 14
    $self->add_to_insert_feature_cvtermprops(
        {   type_id => $self->find_or_create_cvterm_id(
                cv     => $self->extra_cv,
                cvterm => $self->date_column,
                dbxref => $self->date_column,
                db     => $self->extra_db
            ),
            value => $anno->date_compact
        }
    );

    ## -- source column 15
    $self->add_to_insert_feature_cvtermprops(
        {   type_id => $self->find_or_create_cvterm_id(
                cv     => $self->extra_cv,
                cvterm => $self->source_column,
                dbxref => $self->source_column,
                db     => $self->extra_db
            ),
            value => $anno->source->id
        }
    );

    ## -- with column 8
    if ( my $with_field = $self->has_with_field($anno) ) {
        my $values = $self->parse_with_field($with_field);
        for my $i ( 0 .. scalar @$values - 1 ) {
            $self->add_to_insert_feature_cvtermprops(
                {   type_id => $self->find_or_create_cvterm_id(
                        cv     => $self->extra_cv,
                        cvterm => $self->with_column,
                        dbxref => $self->with_column,
                        db     => $self->extra_db
                    ),
                    value => $values->[$i],
                    rank  => $i
                }
            );
        }
    }

## -- extra qualifiers
    my $qual = $anno->qualifier_list;
    if ( defined $qual ) {
        for my $entry ( grep { $_->id ne 'not' } @$qual ) {
            $self->add_to_insert_feature_cvtermprops(
                {   type_id => $self->find_or_create_cvterm_id(
                        cv     => $self->extra_cv,
                        cvterm => $self->qualifier_column,
                        dbxref => $self->qualifier_column,
                        db     => $self->extra_db
                    ),
                    value => $entry->id,
                }
            );
        }
    }
    return 1;
}

__PACKAGE__->meta->make_immutable;

1;

package GAFEngine::Oracle;
use namespace::autoclean;
use Bio::Chado::Schema;
use Moose::Role;

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

sub _preload_evcode_cache {
    my ($self) = @_;
    my $chado  = $self->chado;
    my $rs     = $chado->resultset('Cv::Cv')
        ->search( { 'name' => { -like => 'evidence_code%' } } );
    return if !$rs->count;

    my $syn_rs = $rs->first->cvterms->search_related(
        'cvtermsynonyms',
        {   'type.name' => { -in => [qw/EXACT RELATED/] },
            'cv.name'   => 'synonym_type'
        },
        { join => [ { 'type' => 'cv' } ] }
    );

    for my $syn ( $syn_rs->all ) {
        $self->add_to_evcode_cache( $syn->synonym_, $syn );
        $self->_rev_add_to_evcode_cache( $syn->cvterm->cvterm_id,
            $syn->synonym_ );
    }
}

1;

package GAFEngine::Postgresql;
use namespace::autoclean;
use Moose::Role;

sub setup {
    return 1;
}

sub _preload_evcode_cache {
    my ($self) = @_;
    my $chado  = $self->chado;
    my $rs     = $chado->resultset('Cv::Cv')
        ->search( { 'name' => { -like => 'evidence_code%' } } );
    return if !$rs->count;

    my $syn_rs = $rs->first->cvterms->search_related(
        'cvtermsynonyms',
        {   'type.name' => { -in => [qw/EXACT RELATED/] },
            'cv.name'   => 'synonym_type'
        },
        { join => [ { 'type' => 'cv' } ] }
    );
    for my $syn ( $syn_rs->all ) {
        $self->add_to_evcode_cache( $syn->synonym, $syn );
        $self->_rev_add_to_evcode_cache( $syn->cvterm->cvterm_id,
            $syn->synonym );
    }
}

1;

package GAFLoader;
use namespace::autoclean;
use MooseX::Params::Validate;
use Moose;
use Try::Tiny;
use Carp;
use Data::Dumper::Concise;
use List::MoreUtils qw/uniq/;
use Set::Object;
use DateTime::Format::Strptime;

has 'logger' => (
    is  => 'rw',
    isa => 'Object',
);

has 'manager' => (
    is  => 'rw',
    isa => 'GAFManager'
);

has 'helper' => (
    is      => 'rw',
    isa     => 'GAFHelper',
    handles => {
        'is_from_pubmed'       => 'is_from_pubmed',
        'chado'                => 'chado',
        'parse_id'             => 'parse_id',
        'get_anno_ref_records' => 'get_anno_ref_records',
        'get_db_pub_records'   => 'get_db_pub_records',
        'get_db_records'       => 'get_db_records',
        'has_idspace'          => 'has_idspace'
    }
);

has 'resultset' => (
    is  => 'rw',
    isa => 'Str'
);

has 'datetime' => (
    is      => 'rw',
    isa     => 'DateTime::Format::Strptime',
    default => sub {
        DateTime::Format::Strptime->new( pattern => '%Y%m%d' );
    }
);

sub store_cache {
    my ( $self, $cache ) = @_;
    my $chado = $self->chado;
    for my $i ( 0 .. $#$cache ) {
        try {
            $chado->txn_do(
                sub {
                    $chado->resultset( $self->resultset )
                        ->create( $cache->[$i] );
                }
            );
        }
        catch {
            carp "error in inserting $_\n Data dump ", Dumper $cache->[$i],
                "\n";
            $self->logger->fatal("error in inserting $_");
            $self->logger->fatal( Dumper $cache->[$i] );

            ## -- reporting the error
            my $error_str = $self->_get_error_string( $cache->[$i] );
            $self->logger->error("Not loaded:\t$error_str");

        };
    }
}

sub _get_error_string {
    my ( $self, $data_str ) = @_;
    my $chado = $self->chado;

    my ( $gene_id, $goid, $reference_id, $evcode );
    $gene_id
        = $chado->resultset('Sequence::Feature')
        ->find( { feature_id => $data_str->{feature_id} } )
        ->dbxref->accession;

    $goid
        = 'GO:'
        . $chado->resultset('Cv::Cvterm')
        ->find( { cvterm_id => $data_str->{cvterm_id} } )->dbxref->accession;

    my $pub = $chado->resultset('Pub::Pub')
        ->find( { pub_id => $data_str->{pub_id} } );
    if ( $pub->pubplace =~ /pubmed/i ) {
        $reference_id = 'PMID:' . $pub->uniquename;
    }
    else {
        $reference_id = 'REF:' . $data_str->{pub_id};
    }

    for my $props ( @{ $data_str->{feature_cvtermprops} } ) {
        if ( $props->{value} =~ /^\d{1}$/ ) {
            if ( $self->manager->_has_rev_evcode_in_cache( $props->{type_id} )
                )
            {
                $evcode = $self->manager->_get_rev_evcode_from_cache(
                    $props->{type_id} );
                last;
            }
        }
    }
    return sprintf "%s\t%s\t%s\t%s\n", $gene_id, $goid, $reference_id,
        $evcode;
}

sub dicty_update {
    my $self = shift;
    my ($row)
        = pos_validated_list( \@_,
        { isa => 'Bio::Chado::Schema::Sequence::FeatureCvterm' } );

    my $anno        = $self->manager->annotation;
    my $update_flag = 0;

    # -- updated annotation will have a different date flag
    my $date_rs = $row->search_related(
        'feature_cvtermprops',
        { 'type.name' => $self->manager->date_column },
        { join        => 'type', cache => 1 }
    );

    my $exist_dt = $self->datetime->parse_datetime( $date_rs->first->value );
    my $duration = $anno->date - $exist_dt;
    if ( $duration->is_positive ) {    # -- updated annotation
        $date_rs->first->update( { value => $anno->date_compact } );
        $update_flag++;
    }
    else {
        return $update_flag;
    }

    #compare and update qualifier(s) if any
    my $neg_flag = $anno->negated ? 1 : 0;
    if ( $neg_flag != $row->is_not ) {
        $row->update( { is_not => $neg_flag } );
        $self->manager->add_to_update_message('Negated-Qualifier:column 4');
        warn "updating negated flag\n";
    }

    ## -- qualifiers (other than negation)
    $self->update_qualifier($row);

    ## -- all annotation secondary references
    my $anno_ref_rec = Set::Object->new( $self->get_anno_ref_records($anno) );

    ## -- database records that are stored through feature_cvterm_dbxref
    my $db_rec = Set::Object->new( $self->get_db_records($row) );

    ## -- database records that are stored through feature_cvterm_pubprop
    my $db_pub = Set::Object->new( $self->get_db_pub_records($row) );

    ## -- removing reference
    for my $db_id ( $db_rec->difference($anno_ref_rec)->elements )
    {    ## -- database reference removed from annotation
        my $rs = $self->chado->resultset('General::Dbxref')
            ->search( { accession => $db_id }, { cache => 1 } );
        if ( $rs->count ) {
            $row->feature_cvterm_dbxrefs(
                { dbxref_id => $rs->first->dbxref_id } )->delete_all;
            $self->manager->add_to_update_message('DB:Reference-remove');
            $update_flag++;
        }
    }

    for my $pub_id ( $db_pub->difference($anno_ref_rec)->elements )
    {    ## -- database pubmed removed from annotation
        my $rs = $self->chado->resultset('Pub::Pub')
            ->find( { uniquename => $pub_id }, { cache => 1 } );
        if ($rs) {
            $row->feature_cvterm_pubs( { pub_id => $rs->pub_id } )
                ->delete_all;
            $self->manager->add_to_update_message('DB:Reference-remove');
            $update_flag++;
        }
    }

    ## -- adding reference with publication id
    my $db_all = $db_rec + $db_pub;
    for my $anno_ref_id ( $anno_ref_rec->difference($db_all)->elements )
    {    ## -- database pubmed removed from annotation
        my $rs = $self->chado->resultset('Pub::Pub')
            ->find( { uniquename => $anno_ref_id }, { cache => 1 } );
        if ($rs) {
            $row->add_to_feature_cvterm_pubs( { pub_id => $rs->pub_id } );
            $self->manager->add_to_update_message(
                'DB:Reference-secondary_pub');
            $update_flag++;
        }
        else {
            $rs = $self->chado->resultset('General::Dbxref')
                ->search( { accession => $anno_ref_id }, { cache => 1 } );
            if ( !$rs->count ) {
                warn "$anno_ref_id not found: no link created\n";
                next;
            }
            $row->add_to_feature_cvterm_dbxrefs(
                { dbxref_id => $rs->first->dbxref_id } );
            $self->manager->add_to_update_message(
                'DB:Reference-secondary_dbxref');
            $update_flag++;
        }
    }
    return $update_flag;

}

sub update {
    my $self = shift;
    my ($row)
        = pos_validated_list( \@_,
        { isa => 'Bio::Chado::Schema::Sequence::FeatureCvterm' } );

    my $anno        = $self->manager->annotation;
    my $update_flag = 0;

    # -- updated annotation will have a different date flag
    my $date_rs = $row->search_related(
        'feature_cvtermsynonyms',
        { 'type.name' => $self->manager->date_column },
        { join        => 'type', cache => 1 }
    );

    my $exist_dt = $self->datetime->parse_datetime( $date_rs->first->value );
    my $duration = $anno->date - $exist_dt;
    if ( $duration->is_positive ) {    # -- updated annotation
        $date_rs->first->update( { value => $anno->date_compact } );
        $update_flag++;
    }
    else {
        return $update_flag;
    }

    #compare and update qualifier(s) if any
    my $neg_flag = $anno->negated ? 1 : 0;
    if ( $neg_flag != $row->is_not ) {
        $row->update( { is_not => $neg_flag } );
        $self->manager->add_to_update_message('Negated-Qualifier:column 4');
        warn "updating negated flag\n";
    }

    ## -- qualifiers (other than negation)
    $self->update_qualifier($row);

    # primary reference should not be updated no need to check
    ## -- secondary references
    my $anno_ref_rec = Set::Object->new( $self->get_anno_ref_records($anno) );

    ## -- database records that are stored through feature_cvterm_dbxref
    my $db_rec = Set::Object->new( $self->get_db_records($row) );

    ## -- database records that are stored through feature_cvterm_pubprop
    my $db_pub = Set::Object->new( $self->get_db_pub_records($row) );

    ## -- removing reference
    for my $db_id ( $db_rec->difference($anno_ref_rec)->elements )
    {    ## -- database reference removed from annotation
        my $rs = $self->chado->resultset('General::Dbxref')
            ->search( { accession => $db_id }, { cache => 1 } );
        if ( $rs->count ) {
            $row->feature_cvterm_dbxrefs(
                { dbxref_id => $rs->first->dbxref_id } )->delete_all;
            $self->manager->add_to_update_message('DB:Reference-remove');
            $update_flag++;
        }
    }

    for my $pub_id ( $db_pub->difference($anno_ref_rec)->elements )
    {    ## -- database pubmed removed from annotation
        my $rs = $self->chado->resultset('Pub::Pub')
            ->find( { uniquename => $pub_id }, { cache => 1 } );
        if ($rs) {
            $row->feature_cvterm_pubs( { pub_id => $rs->pub_id } )
                ->delete_all;
            $self->manager->add_to_update_message('DB:Reference-remove');
            $update_flag++;
        }
    }

    ## -- adding reference with publication id
    my $db_all = $db_rec + $db_pub;
    for my $anno_ref_id ( $anno_ref_rec->difference($db_all)->elements )
    {    ## -- database pubmed removed from annotation
        my $rs = $self->chado->resultset('Pub::Pub')
            ->find( { uniquename => $anno_ref_id }, { cache => 1 } );
        if ($rs) {
            $row->add_to_feature_cvterm_pubs( { pub_id => $rs->pub_id } );
            $self->manager->add_to_update_message(
                'DB:Reference-secondary_pub');
            $update_flag++;
        }
        else {
            $rs = $self->chado->resultset('General::Dbxref')
                ->search( { accession => $anno_ref_id }, { cache => 1 } );
            if ( !$rs->count ) {
                warn "$anno_ref_id not found: no link created\n";
                next;
            }
            $row->add_to_feature_cvterm_dbxrefs(
                { dbxref_id => $rs->first->dbxref_id } );
            $self->manager->add_to_update_message(
                'DB:Reference-secondary_dbxref');
            $update_flag++;
        }
    }
    return $update_flag;

}

sub update_qualifier {
    my ( $self, $row ) = @_;

    my $anno = $self->manager->annotation;
    my $qual = [ grep { $_->id ne 'not' } $anno->qualifier_list ];
    if ( defined $qual ) {
        my $anno_qual = Set::Object->new( [ map { $_->id } @$qual ] );
        my $db_qual = Set::Object->new( $self->manager->get_db_qual($row) );
        if ( $db_qual->members ) {
            $row->search_related( 'feature_cvtermprops',
                { value => { -like => $_ } } )->delete_all
                for $db_qual->difference($anno_qual)->elements;

            $self->create_qualifier( $row, $_ )
                for $anno_qual->difference($db_qual)->elements;
            $self->manager->add_to_update_message('Qualifier');
        }
        else {    ## -- new qualifiers to create
            $self->create_qualifier( $row, $_ ) for $anno_qual->members;
            $self->manager->add_to_update_message('Qualifier');
        }
    }
}

sub create_qualifier {
    my ( $self, $row, $value ) = @_;
    $self->manager->chado->txn_do(
        sub {
            $row->create_related(
                'feature_cvtermprops',
                {   value   => $value,
                    type_id => $self->manager->find_or_create_cvterm_id(
                        cv     => $self->manager->extra_cv,
                        cvterm => $self->manager->qualifier_column,
                        dbxref => $self->manager->qualifier_column,
                        db     => $self->manager->extra_db
                    ),

                }
            );
        }
    );
}

__PACKAGE__->meta->make_immutable;

1;

package GAFRank;
use namespace::autoclean;
use Moose;

has 'rank' => (
    is        => 'rw',
    isa       => 'Int',
    predicate => 'has_rank'
);

has 'row' => (
    is  => 'rw',
    isa => 'Bio::Chado::Schema::Sequence::FeatureCvterm'
);

__PACKAGE__->meta->make_immutable;

1;

package main;

use strict;
use Pod::Usage;
use Getopt::Long;
use YAML qw/LoadFile/;
use Bio::Chado::Schema;
use GOBO::Parsers::GAFParser;
use Data::Dumper::Concise;
use Carp;
use Try::Tiny;

my ( $dsn, $user, $password, $config, $log_file, $logger );
my ( $dicty, $prune );
my $commit_threshold = 1000;
my $attr = { AutoCommit => 1 };

GetOptions(
    'h|help'                => sub { pod2usage(1); },
    'u|user:s'              => \$user,
    'p|pass|password:s'     => \$password,
    'dsn:s'                 => \$dsn,
    'c|config:s'            => \$config,
    'l|log:s'               => \$log_file,
    'ct|commit_threshold:s' => \$commit_threshold,
    'dicty'                 => \$dicty,
    'a|attr:s%{1,}'         => \$attr,
    'prune'                 => \$prune
);

pod2usage("!! gaf input file is not given !!") if !$ARGV[0];

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
    $logger
        = $log_file
        ? Logger->handler($log_file)
        : Logger->handler;
}

my $schema = Bio::Chado::Schema->connect( $dsn, $user, $password, $attr );

my $helper = GAFHelper->new( chado => $schema );
my $manager = GAFManager->new( helper => $helper );
my $loader = GAFLoader->new( manager => $manager );
$loader->helper($helper);
$loader->resultset('Sequence::FeatureCvterm');
$loader->logger($logger);

# -- evidence ontology loaded
if ( !$manager->evcodes_in_cache ) {
    warn '!! Evidence codes ontology needed to be loaded !!!!';
    die
        'Download it from here: http://www.obofoundry.org/cgi-bin/detail.cgi?id=evidence_code';
}

if ($prune) {
    $logger->warn("pruning all annotations ......");
    $schema->txn_do(
        sub { $schema->resultset('Sequence::FeatureCvterm')->delete_all } );
    $logger->warn("done with pruning ......");
}

$logger->info("parsing gaf file ....");
my $parser = GOBO::Parsers::GAFParser->new( file => $ARGV[0] );
$parser->parse;
my $graph = $parser->graph;
$logger->info("parsing done ....");

$manager->graph($graph);

my $skipped        = 0;
my $loaded         = 0;
my $updated        = 0;
my $update_skipped = 0;

my $all_anno   = $graph->annotations;
my $anno_count = scalar @$all_anno;
$logger->info("Got $anno_count annotations ....");

my $update_method     = 'update';
my $process_method    = 'process_annotation';
my $process_with_rank = 'process_annotation_with_rank';
my $finder_method     = 'find_annotation';

if ($dicty) {    #dicty specific
    $update_method     = 'dicty_update';
    $process_method    = 'process_dicty_annotation';
    $process_with_rank = 'process_dicty_annotation_with_rank';
    $finder_method     = 'find_dicty_annotation';
}

ANNOTATION:
for my $anno (@$all_anno) {
    $manager->annotation($anno);
    if (!(      $manager->find_annotated
            and $manager->find_term
            and $manager->check_for_evcode
        )
        )
    {    # -- check if any one of the annotated entry, node and evcode exists

        $logger->warn( $manager->skipped_message );
        $skipped++;
        $manager->clear_message;
        next ANNOTATION;
    }

    if ( my $result = $manager->$finder_method ) {  # -- annotation is present
        if ( $result->has_rank )
        {    ## -- annotation probably with different rank
            if ( $manager->$process_with_rank( $result->rank ) ) {
                $manager->keep_state_in_cache;
                $manager->clear_current_state;
            }
            else {
                $logger->warn( $manager->skipped_message );
                $skipped++;
                next ANNOTATION;
            }
        }
        else {    ## -- annotation probably needs update
            if ( !$loader->$update_method( $result->row ) ) {
                $logger->debug(
                    'No update for ', $anno->gene->id,
                    ' and ',          $anno->target->id
                );
                $update_skipped++;
                next ANNOTATION;
            }
            $logger->info(
                $anno->gene->id,
                ' and ',
                $anno->target->id,
                ' been updated with ',
                join( "\t", $manager->get_all_update_message ),
                "\n"
            );
            $updated++;
            $manager->clear_all_update_message;
            next ANNOTATION;
        }
    }
    elsif ( $manager->$process_method ) {    #process for new entries
        $manager->keep_state_in_cache;
        $manager->clear_current_state;
    }
    else {
        $logger->warn( $manager->skipped_message );
        $skipped++;
        next ANNOTATION;
    }

    if ( $manager->entries_in_cache >= $commit_threshold ) {
        my $entries = $manager->entries_in_cache;

        $logger->info("going to load $entries annotations ....");
        $loader->store_cache( $manager->cache );
        $manager->clean_cache;

        $logger->info("loaded $entries annotations ....");
        $loaded += $entries;
        $logger->info(
            "Going to process ",
            $anno_count - $loaded,
            " annotations"
        );
    }
}

if ( $manager->entries_in_cache ) {
    my $entries = $manager->entries_in_cache;
    $logger->info("going to load leftover $entries annotations ....");
    $loader->store_cache( $manager->cache );
    $manager->clean_cache;
    $logger->info("loaded leftover $entries annotations ....");
    $loaded += $entries;
}

$logger->info(
    "Annotations >> Processed:$anno_count Loaded:$loaded  Updated:$updated");
$logger->info("Update-skipped:$update_skipped Loading-skipped:$skipped");

=head1 NAME

B<gaf2chado.pl> - [Loads gafv1.0/2.0 annotations in chado database]

=head1 SYNOPSIS

perl gaf2chado.pl [options] <gaf file>

perl gaf2chado.pl --dsn "dbi:Pg:dbname=gmod" -u tucker -p halo myanno.gaf

perl gaf2chado.pl --dsn "dbi:Oracle:sid=modbase;host=localhost" -u tucker -p halo mgi.gaf

perl gaf2chado.pl -c config.yaml -l output.txt dicty.gaf


=head1 REQUIRED ARGUMENTS

gaf file                 gaf annotation file

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

--prune               delete all annotations before loading,  default is off

=head2 Yaml config file format

 database:
  dsn:'....'
  user:'...'
  password:'.....'
 log: '...'



=head1 DESCRIPTION

The loader assumes the annotated entries(refered in column 1-3, 10, 11 and 12) and
reference(column 6) are already present in the database. 


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



