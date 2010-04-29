#!/usr/bin/perl -w

use strict;
use local::lib '~/dictyBase/Libs/modern-perl';
use Pod::Usage;
use Bio::Chado::Schema;
use Bio::Index::Blast;
use List::MoreUtils qw/any/;
use Try::Tiny;
use autodie;
use Time::Piece;
use Path::Class::File;
use Path::Class::Dir;
use FindBin qw/$Bin/;
use YAML qw/LoadFile/;

my $conf_file
    = Path::Class::Dir->new($Bin)->parent->parent->subdir( 'data', 'config' )
    ->file('report.yaml')->stringify;
pod2usage(
    "!!!! configuration file is not found: report to the author of this script"
) if !-e $conf_file;

my $config = LoadFile($conf_file);

my $db_config = $config->{database};
my $dsn       = $db_config->{dsn};
my $user      = $db_config->{user};
my $pass      = $db_config->{pass};
my $idx       = Path::Class::File->new( $config->{blast}->{folder},
    $config->{blast}->{index} );

pod2usage(
    "!!!! blast index file not found: report to the author of this script")
    if !-e $idx->stringify;


my $t = localtime;
my $out
    = Path::Class::Dir->new($Bin)->parent->parent->subdir( 'data', 'report' )
    ->file( 'curator_report_' . $t->mdy . '_' . $t->hms(':') . '.txt' )
    ->stringify;

my $logfile
    = Path::Class::Dir->new($Bin)->parent->parent->subdir('log')
    ->file( 'curator_report_log_' . $t->mdy . '_' . $t->hms(':') . '.txt' )
    ->stringify;

my $option = { LongReadLen => 2**25 };

pod2usage("no blast index file name given") if !$idx;

my $log    = MyLogger->file_logger($logfile);
my $writer = Path::Class::File->new($out)->openw;
my $blast  = Bio::Index::Blast->new( -filename => $idx->stringify );
my $schema = Bio::Chado::Schema->connect( $dsn, $user, $pass, $option );

$writer->print(
    "Gene_ID\tReprediction\tProtein_Sequence_Length(aa)\tEST_count\tDpur_hit\te-value\tpercent_identity\n\n"
);


my $gene_rs = $schema->resultset('Sequence::Feature')->search(
    {   'type.name'     => 'gene',
        'me.is_deleted' => 0,
        'me.name'       => [
            -and => { -not_like => '%_TE' },
            { -not_like => '%RTE' },
            { -not_like => '%_ps' }
        ]
    },
    {   join     => [qw/type dbxref/],
        prefetch => [qw/dbxref/],
    }
);

my $uncurated = 0;

GENE:
while ( my $gene = $gene_rs->next ) {

    my $trans_rs = $gene->feat_relationship_object_ids->search_related(
        'subject',
        { 'type.name' => [qw/mRNA pseudogene/] },
        { join        => 'type' }
    );

    my $gene_id   = $gene->dbxref->accession;
    my $gene_name = $gene->name;

    if ( $trans_rs->count == 0 ) {
        $log->warn("skipped curated $gene_id");
        next GENE;
    }

    my $transcript;

    #checking for curated model
    while ( my $row = $trans_rs->next ) {
        if ( any { $_->accession eq 'dictyBase Curator' }
            $row->secondary_dbxrefs )
        {
        	$log->warn("skipped curated $gene_id");	
            next GENE;
        }
        $transcript = $row;
    }

    my $floc_row = $gene->featureloc_feature_ids->single;
    if ( !$floc_row ) {
        warn "gene with no location", $gene->dbxref->accession, "\n";
        $log->warn( "gene with no location ", $gene->dbxref->accession );
        next GENE;
    }

    my $start  = $floc_row->fmin;
    my $end    = $floc_row->fmax;
    my $src_id = $floc_row->srcfeature_id;

    #overlapping ESTs
    my $where = {
        -and => [
            -or => [
                -and => [
                    'featureloc_feature_ids.fmin' => { '<=', $start },
                    'featureloc_feature_ids.fmax' => { '>',  $start },
                    'featureloc_feature_ids.fmax' => { '<=', $end },
                ],
                -and => [
                    'featureloc_feature_ids.fmin' => { '>=', $start },
                    'featureloc_feature_ids.fmin' => { '<',  $end },
                    'featureloc_feature_ids.fmax' => { '>=', $end },
                ],
                -and => [
                    'featureloc_feature_ids.fmin' => { '>=', $start },
                    'featureloc_feature_ids.fmax' => { '<=', $end },
                ],
            ],
            'type.name'                            => 'EST',
            'featureloc_feature_ids.srcfeature_id' => $src_id,
        ]
    };

    my $repred_where = {
        'type.name'                            => 'mRNA',
        'featureloc_feature_ids.srcfeature_id' => $src_id,
        'featureloc_feature_ids.fmin'          => { '>=', $start },
        'featureloc_feature_ids.fmax'          => { '<=', $end },
        'dbxref.accession'                     => 'geneID reprediction'
    };

    my $est_count = $schema->resultset('Sequence::Feature')->count(
        $where,
        {   join   => [qw/featureloc_feature_ids type/],
            select => { 'count' => 'feature_id' }
        }
    );

    my $repred       = 'no';
    my $repred_trans = $schema->resultset('Sequence::Feature')->search(
        $repred_where,
        {   join => [
                'featureloc_feature_ids', 'type',
                { 'feature_dbxrefs' => 'dbxref' }
            ],
            rows => 1,
        }
    )->single;

    $log->info(" writing report for $gene_id $gene_name ");
    $uncurated++;

    if ($repred_trans) {
        $repred = 'yes' if feature_matches( $transcript, $repred_trans );
    }

    my $seqlen = seqlen($transcript);

    #-- now generate the report

    #blast hit lookup
    my $result;
    try {
        $result = $blast->fetch_report($gene_id);

        #no result or no hit
        if ( !$result or $result->num_hits == 0 ) {
            $writer->print( $gene_id, "\t$repred\t$seqlen\t", $est_count,
                "\tno\n" );
        }
        else {
            my $hit        = $result->next_hit;
            my $hsp        = $hit->hsp;
            my $hit_name   = ( ( split( /\|/, $hit->name ) )[1] );
            my $out_string = sprintf "%s\t%s\t%d\t%d\tyes\t%s\t%s\t%d%%\n",
                $gene_id, $repred, $seqlen, $est_count, $hit_name,
                $hsp->evalue, $hsp->frac_identical * 100;
            $writer->print($out_string);
        }

    }
    catch {
        $log->info(" Issue getting blast result for $gene_id => $_ ");
        $writer->print( $gene_id, "\t$repred\t$seqlen\t", $est_count,
            "\tno\n" );
    };

}

$writer->close;
$log->info("Total gene reported: $uncurated");

sub seqlen {
    my ($trans) = @_;
    my $poly = $trans->search_related(
        'feat_relationship_object_ids',
        { 'type.name' => 'derived_from' },
        { join        => 'type' }
        )->search_related(
        'subject',
        { 'type_2.name' => 'polypeptide' },
        { join          => 'type', row => 1 }
        )->single;
    $poly->seqlen;
}

sub feature_matches {
    my ( $trans, $repred_trans ) = @_;

    #get all exons with its coordinates
    my @trans_exons = $trans->feat_relationship_object_ids->search_related(
        'subject',
        { 'type.name' => 'CDS' },
        { join        => 'type' },
        )
        ->search_related( 'featureloc_feature_ids', {},
        { order_by => { -asc => 'featureloc_feature_ids.fmin' } } );

    my @repred_exons
        = $repred_trans->feat_relationship_object_ids->search_related(
        'subject',
        { 'type.name' => 'CDS' },
        { join        => 'type' },
        )
        ->search_related( 'featureloc_feature_ids', {},
        { order_by => { -asc => 'featureloc_feature_ids.fmin' } } );

    #should have equal number of exons
    return 0 if $#trans_exons != $#repred_exons;

    my ( @texons_loc, @rexons_loc );
    push @texons_loc, $_->fmin, $_->fmax for @trans_exons;
    push @rexons_loc, $_->fmin, $_->fmax for @repred_exons;

    #now comapre them
    for my $i ( 0 .. $#texons_loc ) {
        return 0 if $texons_loc[$i] != $rexons_loc[$i];
    }
    return 1;

    #$log->print(
    #    $trans->uniquename, " \t ", scalar @trans_exons, " \t ",
    #    join( " \t ", @texons_loc ), " \t "
    #);
    #$log->print(
    #    $repred_trans->uniquename, " \t ", scalar @repred_exons, " \t ",
    #    join( " \t ", @rexons_loc ), " \n "
    #);
}

package MyLogger;

use Log::Log4perl qw/:easy/;
use Log::Log4perl::Appender;
use Log::Log4perl::Layout::PatternLayout;

sub file_logger {
    my ( $class, $file ) = @_;
    my $appender
        = Log::Log4perl::Appender->new( 'Log::Log4perl::Appender::File',
        filename => $file );

    my $layout = Log::Log4perl::Layout::PatternLayout->new(
        "[%d{MM-dd-yyyy hh:mm}] %p > %F{1}:%L - %m%n");

    my $log = Log::Log4perl->get_logger($class);
    $appender->layout($layout);
    $log->add_appender($appender);
    $log->level($DEBUG);
    $log;
}

1;

__END__


=head1 NAME

B<curation_report_standalone.pl> - [Report gives a list of uncurated genes along with est count and
presence or absence of blast hit]


=head1 SYNOPSIS

perl curation_report_standalone.pl  #Expected to be run by curators 


=head1 REQUIRED ARGUMENTS

=for author to fill in:
A complete list of every argument that must appear on the command line.
when the application  is invoked, explaining what each of them does, any
restrictions on where each one may appear (i.e., flags that must appear
before or after filenames), and how the various arguments and options
may interact (e.g., mutual exclusions, required combinations, etc.)
If all of the application's arguments are optional, this section
may be omitted entirely.


=head1 OPTIONS

B<[-h|-help]> - display this documentation.

=for author to fill in:
	A complete list of every available option with which the application
	can be invoked, explaining what each does, and listing any restrictions,
	or interactions.
	If the application has no options, this section may be omitted entirely.


=head1 DESCRIPTION

This script assumes a correct yaml configuration file is present in the config folder of
this distribution. 

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

Bio::Chado::Schema

Try::Tiny

autodie

Log::Log4perl

Bio::Index::Blast

Path::Class

=head1 BUGS AND LIMITATIONS

=head1 TODO

Start getting the genes from chromosomes,  in that case the orphan genes could be avoided

=for author to fill in:
	A list of known problems with the module, together with some
	indication Whether they are likely to be fixed in an upcoming
	release. Also a list of restrictions on the features the module
	does provide: data types that cannot be handled, performance issues
	and the circumstances in which they may arise, practical
	limitations on the size of data sets, special cases that are not
	(yet) handled, etc.

	No bugs have been reported.Please report any bugs or feature requests to

	B<Siddhartha Basu>


=head1 AUTHOR

	I<Siddhartha Basu>  B<siddhartha-basu@northwestern.edu>

=head1 LICENCE AND COPYRIGHT

	Copyright (c) B<2009>, Siddhartha Basu C<<siddhartha-basu@northwestern.edu>>. All rights reserved.

	This module is free software; you can redistribute it and/or
	modify it under the same terms as Perl itself. See L<perlartistic>.



