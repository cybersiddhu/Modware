#!/usr/bin/perl -w

use strict;
use local::lib '~/dictyBase/Libs/modern-perl';
use Pod::Usage;
use Getopt::Long;
use Bio::SearchIO;
use Bio::Chado::Schema;
use Try::Tiny;
use YAML qw/LoadFile/;
use Log::Log4perl qw/:easy/;
use Log::Log4perl::Appender;
use Log::Log4perl::Layout::PatternLayout;

my ($dsn,       $user,       $pass,   $query_type, $update,
    $query_org, $target_org, $config, $sql_verbose
);
my $verbose;
my $db_source  = 'GFF_source';
my $seq_onto   = 'sequence';
my $option     = { LongReadLen => 2**15 };
my $match_type = 'match';

GetOptions(
    'h|help'             => sub { pod2usage(1); },
    'qorg|query_org:s'   => \$query_org,
    'torg|target_org:s'  => \$target_org,
    'qtype|query_type:s' => \$query_type,
    'dsn=s'              => \$dsn,
    'u|user=s'           => \$user,
    'p|pass|password=s'  => \$pass,
    'so|seq_onto:s'      => \$seq_onto,
    'mt|match_type:s'    => \$match_type,
    'v|verbose'          => \$verbose,
    'sql_verbose'        => \$sql_verbose,
    'c|config:s'         => \$config
);

if ($config) {
    my $str = LoadFile($config);
    my $db  = $str->{database};
    if ($db) {
        $dsn  = $db->{dsn}      || $dsn;
        $user = $db->{user}     || $user;
        $pass = $db->{password} || $pass;
    }
    my $query = $str->{query};
    if ($query) {
        $query_org  = $query->{organism} || $query_org;
        $query_type = $query->{type}     || $query_type;
    }

    my $target = $str->{target};
    if ($target) {
        $target_org = $target->{organism} || $target_org;
    }

    $seq_onto   = $str->{so}         || $seq_onto;
    $match_type = $str->{match_type} || $match_type;

}

my $logger;
if ($verbose) {
    $logger = setup_logger();
}

my $schema = Bio::Chado::Schema->connect( $dsn, $user, $pass);
$schema->storage->verbose(1) if $sql_verbose;

#check if the sequence ontology namespace exists
my $so = $schema->resultset('Cv::Cv')->find( { name => $seq_onto } );
pod2usage("sequence ontology namespace $seq_onto does not exist") if !$so;

#get the query organism
my $organism;
my $query_clause = {};
if ($target_org) {
    my $organism = $schema->resultset('Organism::Organism')->search(
        {   -or => [
                'common_name'  => $target_org,
                'abbreviation' => $target_org,
                'species'      => $target_org,

            ],
        },
        { 'select' => [qw/species organism_id common_name/], rows => 1 }
    )->single;

    pod2usage("$organism organism does not exist in our database")
        if !$organism;
    $query_clause = { 'organism_id' => $organism->organism_id };

}

my $hit_clause = {
    'type_3.name'  => $match_type,
    'type_3.cv_id' => $so->cv_id,
    'is_analysis'  => 1
};
my $hsp_clause = {
    'type.name'   => 'match_part',
    'type.cv_id'  => $so->cv_id,
    'is_analysis' => 1
};

if ($query_org) {
    my $organism = $schema->resultset('Organism::Organism')->search(
        {   -or => [
                'common_name'  => $query_org,
                'abbreviation' => $query_org,
                'species'      => $query_org,

            ],
        },
        { 'select' => [qw/species organism_id common_name/], rows => 1 }
    )->single;

    pod2usage("$organism organism does not exist in our database")
        if !$organism;
    $hit_clause->{organism_id} = $organism->organism_id;
    $hsp_clause->{organism_id} = $organism->organism_id;

}

#get all HSPs
my $hsp_rs = $schema->resultset('Sequence::Feature')
    ->search( $hsp_clause, { join => 'type' } );

#get all Hits
#If the same relationship name is being used it get aliased by DBIC and which should be
#used
my $hit_rs = $hsp_rs->search_related(
    'feat_relationship_subject_ids',
    {   'type_2.name'  => 'part_of',
        'type_2.cv_id' => $so->cv_id
    },
    { join => 'type' }
)->search_related( 'object', $hit_clause, { join => 'type' } );

#The queries
my $query_rs
    = $hsp_rs->search_related( 'featureloc_feature_ids',
    { 'featureloc_feature_ids.rank' => 1 } )
    ->search_related( 'srcfeature', $query_clause );

#orphan hit if any
my $orphan_hit_rs = $schema->resultset('Sequence::Feature')->search(
    {   'type.name'   => $match_type,
        'is_analysis' => 1,
    },
    { join => 'type' }
);

my $delete_alignment = sub {
    foreach my $rs ( ( $query_rs, $hit_rs, $hsp_rs ) ) {
        my $dbxref_rs = $rs->search_related('dbxref');
        $logger->info(
            'Going to delete  ',
            $dbxref_rs->count,
            ' dbxref records'
        ) if $verbose;
        $dbxref_rs->delete_all;

        $logger->info( 'Going to delete ', $rs->count, ' records' )
            if $verbose;
        $rs->delete_all;

    }
    $orphan_hit_rs->search_related('dbxref')->delete_all;
    $logger->info(
        'Going to delete ',
        $orphan_hit_rs->count,
        ' orphan hit records'
    ) if $verbose;
    $orphan_hit_rs->delete_all;
};

try {
    $schema->txn_do($delete_alignment);
}
catch {
    $logger->warn("Alignment cannot be deleted $_") if $verbose;
    warn "Alignment cannot be deleted $_\n"         if !$verbose;
};

sub setup_logger {
    my $appender
        = Log::Log4perl::Appender->new(
        'Log::Log4perl::Appender::ScreenColoredLevels',
        stderr => 1 );

    my $layout = Log::Log4perl::Layout::PatternLayout->new(
        "[%d{MM-dd-yyyy hh:mm}] %p > %F{1}:%L - %m%n");

    my $log = Log::Log4perl->get_logger();
    $appender->layout($layout);
    $log->add_appender($appender);
    $log->level($DEBUG);
    $log;
}

=head1 NAME

B<prune_alignment.pl> - [Delete all blast alignments from chado database]


=head1 SYNOPSIS

perl prune_alignment.pl -dsn "dbi:Pg:database=mygmod;host=localhost" -u user -p pass

perl prune_alignment.pl -dsn "dbi:Pg:database=mygmod;host=localhost" -u user -p pass -mt
protein_match


perl prune_alignment.pl -dsn "dbi:Oracle:sid=oramod;host=localhost" -u user -p pass -mt
protein_match -qorg fly -torg worm


=head1 REQUIRED ARGUMENTS

B<[-dsn|--dsn]> - dsn for the chado database, to know more about dsn string look at the
documentation of L<DBI> module.

B<[-u|-user]> - database user name 

B<[-p|-pass]> - database password



=head1 OPTIONS

B<[-h|-help]> - display this documentation.

B<[-qorg|-query_org]> - Organism name to which the query sequence belongs to,  will be
used to restrict the query record.

B<[-torg|-target_org]> - Organism name to which the target sequence belongs to,  will be
used to restrict the target record.

B<[-so|seq_onto]> - Sequence ontology namespace under which SO is loaded,  default is
B<sequence>

B<[-mt|-match_type]> - SO term that will be used for hit features in database,  default is
B<match>.

B<[-verbose]> - Turn on displaying of SQL statement that is being used,  default is off.


=head1 DESCRIPTION

The script by default deletes all algnments from chado database that are stored using the
GMOD recommended standardized data model. The details of the data model is described here
....

L<http://gmod.org/wiki/Chado_Companalysis_Module#General_implementation>
L<http://gmod.org/wiki/Chado_Tutorial#Example:_Computational_Analysis>

Of course,  the entries to be removed can be fine tuned using the provided command line
parameters. 


=head1 DIAGNOSTICS

The entire deletion is done in a single transaction,  in case of any failure the script is
aborted.

=head1 CONFIGURATION AND ENVIRONMENT

None.

=head1 DEPENDENCIES

Bio::Chado::Schema

Try::Tiny

=head2 Optional dependencies[Depending on database server] 

DBD::mysql 

DBD::Pg

DBD::Oracle


=head1 BUGS AND LIMITATIONS

On each only one particular type of hit features will be deleted. For example, if the
chado instance has various kinds of match feature such as B<match>,  B<protein_match>,
B<nucleotide_match> only one of them can be selected at a time.  

=head1 TO DO

To get rid of limitation described above by getting a list of match and its descendents
from the Cvterm table of chado. 

=head1 AUTHOR

I<Siddhartha Basu>  B<siddhartha-basu@northwestern.edu>

=head1 LICENCE AND COPYRIGHT

Copyright (c) B<2009>, Siddhartha Basu C<<siddhartha-basu@northwestern.edu>>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.



