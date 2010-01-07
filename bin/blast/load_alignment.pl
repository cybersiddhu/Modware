#!/usr/bin/perl -w

use strict;
use Pod::Usage;
use Getopt::Long;
use Bio::SearchIO;
use Bio::Chado::Schema;
use Try::Tiny;

my ( $dsn, $user, $pass, $query_org, $query_type, $update );
my $query_parser = 'none';
my $hit_parser   = 'none';
my $db_source    = 'GFF_source';
my $source       = 'dictyBase_blast';
my $seq_onto     = 'sequence';
my $option       = { LongReadLen => 2**15 };

GetOptions(
    'h|help'             => sub { pod2usage(1); },
    'qorg|query_org=s'   => \$query_org,
    'qtype|query_type:s' => \$query_type,
    'dsn=s'              => \$dsn,
    'u|user=s'           => \$user,
    'p|pass|password=s'  => \$pass,
    'opt|dbopt:s'        => \$option,
    'qp|query_parser:s'  => \$query_parser,
    'hp|hit_parser:s'    => \$hit_parser,
    's|src|source:s'     => \$source,
    'so|seq_onto:s'      => \$seq_onto,
    'update'             => \$update,
    'db_src|db_source'   => \$db_source,
);

pod2usage("no blast alignment file is given") if !$ARGV[0];

my %type_map = (
    blastn  => 'DNA',
    blastp  => 'protein',
    tblastn => 'protein',
    blastx  => 'DNA',
    tblastx => 'DNA',
);

my %match_map = (
    blastn  => 'nucleotide_match',
    blastp  => 'protein_match',
    tblastn => 'protein_match',
    blastx  => 'translated_protein_match',
    tblastx => 'translated_protein_match',
);

my %query_parser_map = (
    'ncbi'    => sub { ( ( split /\|/, $_[0] ) )[1] },
    'regular' => sub { ( ( split /\|/, $_[0] ) )[0] },
    'dicty'   => sub {
        my $id = ( ( split /\|/, $_[0] ) )[1];
        $id =~ s/\s+$//;
        $id;
    },
    'none' => sub { my $id = $_[0]; $id =~ s/\s+$//; $id; }
);

my %hit_parser_map = (
    'ncbi'    => sub { ( ( split /\|/, $_[0] ) )[1] },
    'regular' => sub { ( ( split /\|/, $_[0] ) )[0] },
    'dicty'   => sub {
        my $id = ( ( split /\|/, $_[0] ) )[0];
        $id =~ s/\s+$//;
        $id;

    },
    'none' => sub { my $id = $_[0]; $id =~ s/\s+$//; $id; }
);

my $searchio = Bio::SearchIO->new( -file => $ARGV[0], -format => 'blast' );
my $schema = Bio::Chado::Schema->connect( $dsn, $user, $pass );

#check if the sequence ontology namespace exists
my $so = $schema->resultset('Cv::Cv')->find( { name => $seq_onto } );
pod2usage("sequence ontology namespace $seq_onto does not exist") if !$so;

#get the dbsource
my $db = $schema->resultset('General::Db')->find( { name => $db_source } );

if ( !$db ) {
    try {
        $db = $schema->txn_do(
            sub {
                $schema->resultset('General::Db')
                    ->create( { name => $db_source } );
            }
        );
    }
    catch {
        die "unable to create source record $source $_";
    };
}

my $dbxref;
try {
    $dbxref = $schema->txn_do(
        sub {
            $schema->resultset('General::Dbxref')->find_or_create(
                {   accession => $source,
                    db_id     => $db->db_id
                }
            );
        }
    );
}
catch {
    die "unable to create dbxref record for source: $source $_ \n";
};

my $match_part = $schema->resultset('Cv::Cvterm')->find(
    {   name  => 'match_part',
        cv_id => $so->cv_id
    }
);

pod2usage("unable to fetch *match_part* cvterm:  please insert that first")
    if !$match_part;

my $part_of = $schema->resultset('Cv::Cvterm')
    ->find( { name => 'part_of', cv_id => $so->cv_id }, );

my $description
    = $schema->resultset('Cv::Cvterm')->find( { name => 'description' } );

pod2usage("unable to find description cvterm in database") if !$description;

#get the query organism
my $organism = $schema->resultset('Organism::Organism')->search(
    {   -or => [
            'common_name'  => $query_org,
            'abbreviation' => $query_org,
            'species'      => $query_org,

        ],
    },
    { 'select' => [qw/species organism_id common_name/], rows => 1 }
)->single;

pod2usage("$organism organism does not exist in our database") if !$organism;

my $analysis;
my $match_type;

RESULT:
while ( my $result = $searchio->next_result ) {
    next RESULT if $result->no_hits_found;

    $analysis
        ||= $schema->resultset('Companalysis::Analysis')->find_or_create(
        {   program        => $result->algorithm,
            programversion => $result->algorithm_version,
            sourcename     => $source,
            name           => $result->algorithm . '_' . $source,
            description    => $result->algorithm . ' alignment'
        }
        );

    $query_type
        ||= $schema->resultset('Cv::Cvterm')
        ->find(
        { name => $type_map{ lc $result->algorithm }, cv_id => $so->cv_id } );
    $match_type
        ||= $schema->resultset('Cv::Cvterm')
        ->find(
        { name => $match_map{ lc $result->algorithm }, cv_id => $so->cv_id }
        );

    my $query_id  = $query_parser_map{$query_parser}->( $result->query_name );
    my $query_row = $schema->resultset('Sequence::Feature')->search(
        {   -and => [
                'is_deleted' => 0,
                -or          => [
                    'dbxref.accession' => $query_id,
                    'uniquename'       => $query_id,
                    'name'             => $query_id
                ]
            ]
        },
        {   join   => 'dbxref',
            select => [qw/feature_id type_id uniquename name/],
            rows   => 1
        }
    )->single;

    if ( !$query_row ) {
        my $create = sub {
            $schema->resultset('Sequence::Feature')->create(
                {   uniquename  => $query_id,
                    name        => $query_id,
                    organism_id => $organism->organism_id,
                    is_analysis => 1,
                    type_id     => $query_type->cvterm_id,
                    dbxref      => {
                        accession => $query_id,
                        db_id     => $db->db_id
                    },
                }
            );
        };
        try {
            $query_row = $schema->txn_do($create);
        }
        catch {
            warn "failed to create record for $query_id $_";
            next;
        };
    }

    remove_alignments($query_row) if $update;

HIT:
    while ( my $hit = $result->next_hit ) {
        my $hit_id     = $hit_parser_map{$hit_parser}->( $hit->name );
        my $target_row = $schema->resultset('Sequence::Feature')->search(
            {   -and => [
                    'is_deleted' => 0,
                    -or          => [
                        'uniquename'       => $hit_id,
                        'dbxref.accession' => $hit_id,
                        'name'             => $hit_id
                    ]
                ]
            },
            {   join     => 'dbxref',
                'select' => [qw/feature_id organism_id/],
                rows     => 1
            }

        )->single;

        if ( !$target_row ) {
            warn "unable to find hit for hit id: $hit_id\n";
            next HIT;
        }

		#additional grouping of hsp's by the hit strand as in case of tblastn hsp
		#belonging to separate strand of query could be grouped into the same hit,  however
		#they denotes separate matches and should be separated.
        my $hsp_group;
        while ( my $hsp = $hit->next_hsp ) {
            my $strand = $hsp->strand('hit') == 1 ? 'plus' : 'minus';
            push @{ $hsp_group->{$strand} }, $hsp;
        }

    STRAND:
        foreach my $strand ( keys %$hsp_group ) {
            my $hit_value = sprintf "%s:%s-%s", $query_id, $hit_id, $strand;
            my $hit_create = sub {
                my $hit_row = $schema->resultset('Sequence::Feature')->create(
                    {   uniquename  => $hit_value,
                        name        => $hit_value,
                        organism_id => $target_row->organism_id,
                        is_analysis => 1,
                        seqlen      => $hit->length,
                        type_id     => $match_type->cvterm_id,
                        dbxref      => {
                            accession => $hit_value,
                            db_id     => $db->db_id
                        },
                        analysisfeatures => [
                            {   analysis_id  => $analysis->analysis_id,
                                rawscore     => $hit->bits,
                                normscore    => $hit->score,
                                significance => $hit->significance
                            }
                        ],
                        feature_dbxrefs =>
                            [ { dbxref_id => $dbxref->dbxref_id } ]
                    }
                );
                my $floc_row = $schema->resultset('Sequence::Featureloc')
                    ->create( { feature_id => $hit_row->feature_id } );
                $floc_row->srcfeature_id( $target_row->feature_id );
                $floc_row->rank(0);
                $floc_row->strand( $hit->strand('hit') );
                $floc_row->fmin( $hit->start('hit') - 1 );
                $floc_row->fmax( $hit->end('hit') );
                $floc_row->update;

                $hit_row;
            };

            my $hit_row;
            try {
                $hit_row = $schema->txn_do($hit_create);
            }
            catch {
                warn "cannot create record for hit $hit_id $_";
                next STRAND;
            };

        HSP:
            foreach my $hsp ( @{ $hsp_group->{$strand} } ) {
                my $hsp_id = generate_uniq_id( $query_id, $hit_value, $hsp );
                my $hsp_create = sub {
                    $schema->resultset('Sequence::Feature')->create(
                        {   uniquename  => $hsp_id,
                            name        => $hsp_id,
                            organism_id => $hit_row->organism_id,
                            is_analysis => 1,
                            type_id     => $match_part->cvterm_id,
                            seqlen      => $hsp->length,
                            dbxref      => {
                                accession => $hsp_id,
                                db_id     => $db->db_id
                            },
                            featureloc_feature_ids => [
                                {   'srcfeature_id' => $query_row->feature_id,
                                    'rank'          => 1,
                                    'strand'        => $hsp->strand('hit'),
                                    'fmin' => $hsp->start('query') - 1,
                                    'fmax' => $hsp->end('query'),

                                },
                                {   'srcfeature_id' =>
                                        $target_row->feature_id,
                                    'rank'   => 0,
                                    'strand' => $hsp->strand('hit'),
                                    'fmin'   => $hsp->start('subject') - 1,
                                    'fmax'   => $hsp->end('subject'),

                                },
                            ],
                            analysisfeatures => [
                                {   analysis_id  => $analysis->analysis_id,
                                    rawscore     => $hsp->bits,
                                    normscore    => $hsp->score,
                                    significance => $hsp->significance,
                                    identity     => $hsp->percent_identity,
                                }
                            ],
                            feat_relationship_subject_ids => [
                                {   type_id   => $part_of->cvterm_id,
                                    object_id => $hit_row->feature_id,
                                    rank      => $hsp->rank,
                                },
                            ],
                        }
                    );
                };

                try {
                    my $hsp_row = $schema->txn_do($hsp_create);
                }
                catch {
                    warn "Unable to create hit record for $hit_id $_";
                };

            }
        }
    }
}

sub generate_uniq_id {
    my ( $query, $hit, $hsp ) = @_;
    sprintf "%s:%s:%d..%d::%d..%d", $query, $hit,
        $hsp->start('query'),
        $hsp->end('query'),
        $hsp->start('subject'), $hsp->end('subject');

}

sub remove_alignments {
    my $query = shift;

    #get all HSPs
    my $hsp_rs
        = $query->featureloc_srcfeature_ids->search( { 'rank' => 1 } )
        ->search_related(
        'feature',
        { 'type.name' => 'match_part', is_analysis => 1 },
        { join        => 'type' }
        );
    return if $hsp_rs->count == 0;

#get all Hits
#If the same relationship name is being used it get aliased by DBIC and which should be
#used
    my $hit_rs = $hsp_rs->search_related(
        'feat_relationship_subject_ids',
        {   'type_2.name'  => 'part_of',
            'type_2.cv_id' => $query->type->cv_id
        },
        { join => 'type' }
    )->search_related( 'object', { 'is_analysis' => 1 }, );

    try {
        $schema->txn_do(
            sub {
                foreach my $rs ( ( $hit_rs, $hsp_rs ) ) {
                    $rs->search_related('dbxref')->delete_all;
                    $rs->delete_all;
                }

            }
        );
    }
    catch {
        warn 'unable to clean alignment for query ', $query->name, " $_\n";
        return;
    };

}

=head1 NAME

B<load_alignment.pl> - [Load blast alignment in chado database]


=head1 SYNOPSIS

perl load_alignment.pl -dsn "dbi:Oracle:host=localhost;sid=oraclesid" -u user -p pass
-qorg worm blast_data.out`:w


perl load_alignment.pl -dsn "dbi:Oracle:host=localhost;sid=oraclesid" -u user -p pass
-qorg dicty -hp dicty -qp dicty blast_data.out


perl load_alignment.pl -dsn "dbi:Pg:host=localhost;database=mygmod" -u user -p pass
-qorg fly -hp ncbi -qp regular blast_data.out

perl load_alignment.pl -dsn "dbi:Pg:host=localhost;database=mygmod" -u user -p pass
-qorg fly --update blast_data.out


=head1 REQUIRED ARGUMENTS

B<[-dsn|--dsn]> - dsn for the chado database, to know more about dsn string look at the
documentation of L<DBI> module.

B<[-u|-user]> - database user name 

B<[-p|-pass]> - database password

B<[-qorg|-query_org]> - Organism name to which the query sequence belongs to,  will be
used to store the query record.

=head1 OPTIONS

B<[-h|-help]> - display this documentation.

B<[-qtype|query_type]> - Sequence ontology(SO) cvterm that will be used for storing the
query record. By default,  it will be choosen from the type of blast search performed. The
following map is being used by the program to decide that .....

=over

=item

blastn => nucleotide_match

=item

blastp or tblastn => protein_match

=item

blastx or tblastx => translated_protein_match

=back


B<[-qp|-query_parser]> - The parser that will be used to extract the query Id from the
query blast header. Three parsers are available B<ncbi>, B<regular> and B<dicty>. By
default,  no parsing is performed. Here are the logic of the available parsers ...

=over

=item

ncbi : The first Id that comes after gi.

=item

regular : It assumes there are at least 2 or more Ids present in the header separated by
pipe(|) character. It returns the 2nd one.


=item

dicty : It is specific to header generated by dictyBase software. 

=back

B<[-hp|-hit_parser]> - Works on blast header of the hit entry,  works exactly like the
query parser option.

B<[-s|-src|-source]> - The source name that will be linked to every hit entry and
ultimately can be used in the gbrowse configuration after the method name. It will be
stored in accession of dbxref table linked via feature_dbxref table. By default,
B<dictyBase_blast> is used.

B<[-so|seq_onto]> - Sequence ontology namespace under which SO is loaded,  default is
B<sequence>

B<[-update]> - Updates the alignments,  here the loader tries to find the query in the
database after parsing the header. If found,  it deletes all Hit and HSPs that are linked
to each of them. Then it creates new entires as it happens in case of a run without update
flag.

B<[-db_src|db_source]> - Name of the database authority to which every entry will be tied
to in this blast loading. By default B<GFF_source> will be used.

=head1 DESCRIPTION

The blast data is loaded following the best practices of GMOD community,  particular
making it compatible with bulk GFF3 loader script. The following storage model is followed
...

------------------------------------------ genome
 		^      ^      ^     ^
 		|   ___|____A_|___  |     alignment feature type = match
 floc   |    ^          ^   | floc (rank = 0)
        |    | f_r  f_r |   |
      --B-----        ----C---     hsp feature type = match_part
             |        | 
        floc |        | floc (rank = 1)
             V        V
             ----D-----  aligned feature type(protein/DNA/EST)     

=over

=item *

The query gets a feature record,  its id gets parsed from its blast header.

=item *

Each hit gets a feature record along with its entry in analysisfeature table. In addition,
the hit also adds a featureloc record tied to the genome. This is done to make it gbrowse
compatible as the gbrowse-chado adaptor needs a featureloc entry for displaying.

=item *

The hsps gets a feature entry along with two featureloc entries both to genome and query
feature and another feature relationship entry with its corresponding hit.

=back


=head2 OTHER FEATURES OF THE SCRIPT

=over

=item *

No attempts is made to store the sequence of query.

=item *

The hit id is parsed from its header and then used to look up for reference
feature(genome) in chado. If absent,  that particular alignment is skipped. So,  it is
neccessary to use id of reference feature in the fasta file of target sequence.

=item *

As per chado database constraint, the unique id of each hit is constructed by combining
both query and hit id. In gbrowse callback,  the query id is parsed for display.

=back


=head1 DIAGNOSTICS

Each insertion is done in its separate transaction. In case of failure,  the scripts warns
and moves on to the next alignment.

=head1 CONFIGURATION AND ENVIRONMENT

None.

=head1 DEPENDENCIES

Bio::Chado::Schema

Bio::SearchIO

Try::Tiny


=head2 Optional dependencies[Depending on database server] 

DBD::mysql 

DBD::Pg

DBD::Oracle


=head1 BUGS AND LIMITATIONS

It does not store any sequences. The HSP alignments is also not stored. 


=head1 AUTHOR

I<Siddhartha Basu>  B<siddhartha-basu@northwestern.edu>

=head1 LICENCE AND COPYRIGHT

Copyright (c) B<2009>, Siddhartha Basu C<<siddhartha-basu@northwestern.edu>>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.



