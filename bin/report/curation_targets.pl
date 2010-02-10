#!/usr/bin/perl -w

use strict;
use local::lib '~/dictyBase/Libs/modern-perl';
use Pod::Usage;
use Getopt::Long;
use Bio::Chado::Schema;
use Bio::Index::Blast;
use List::MoreUtils qw/any/;
use IO::File;
use Try::Tiny;
use autodie;

my ( $dsn, $user, $pass, $idx );
my $out    = 'curator_report.txt';
my $logger = 'output_log.txt';
my $option = { LongReadLen => 2**25 };

GetOptions(
    'h|help'            => sub { pod2usage(1) },
    'dsn=s'             => \$dsn,
    'u|user=s'          => \$user,
    'p|pass|password=s' => \$pass,
    'idx|index=s'       => \$idx,
    'o|out|output:s'    => \$out,
    'l|log:s'           => \$logger,
);

pod2usage("no blast index file name given") if !$idx;

my $writer = IO::File->new( $out,    'w' );
my $log    = IO::File->new( $logger, 'w' );
my $blast = Bio::Index::Blast->new( -filename => $idx );
my $schema = Bio::Chado::Schema->connect( $dsn, $user, $pass, $option );

my $gene_rs = $schema->resultset('Sequence::Feature')->search(
    { 'type.name' => 'gene', 'is_deleted' => 0 },
    {   join     => [qw/type dbxref/],
        prefetch => [qw/dbxref/],
    }
);

GENE:
while ( my $gene = $gene_rs->next ) {
    my $trans_rs = $gene->feat_relationship_object_ids->search_related(
        'subject',
        { 'type.name' => 'mRNA' },
        { join        => 'type', },
    );

    my $gene_id = $gene->dbxref->accession;
    if ( $trans_rs->count == 0 ) {
        $log->print("skipped $gene_id \n");
        next GENE;
    }

    my $transcript;

    #checking for curated model
    while ( my $row = $trans_rs->next ) {
        if ( any { $_->accession =~ /Curator/i } $row->secondary_dbxrefs ) {
            next GENE;
        }
        $transcript = $row;
        last;
    }

    my $floc_row = $gene->featureloc_feature_ids->single;
    if ( !$floc_row ) {
        warn "gene with no location ", $gene->dbxref->accession, "\n";
        $log->print( "gene with no location ",
            $gene->dbxref->accession, "\n" );
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
    $log->print("writing report for $gene_id \n");

    if ($repred_trans) {
        $repred = 'yes' if feature_matches( $transcript, $repred_trans );
    }

    #-- now generate the report

    #blast hit lookup
    my $result;
    try {
        $result = $blast->fetch_report($gene_id);

        #no result or no hit
        if ( !$result or $result->num_hits == 0 ) {
            $writer->print( $gene_id, "\t$repred\t", $est_count, "\tno\n" );
        }
        else {
            my $hit      = $result->next_hit;
            my $hsp      = $hit->hsp;
            my $hit_name = ( ( split( /\|/, $hit->name ) )[1] );

            my $out_string = sprintf "%s\t%s\t%d\tyes\t%s\t%s\t%d%%\n",
                $gene_id, $repred, $est_count, $hit_name, $hsp->evalue,
                $hsp->frac_identical * 100;
            $writer->print($out_string);
        }

    }
    catch {
        $log->print("Issue getting blast result for $gene_id => $_\n");
        $writer->print( $gene_id, "\t$repred\t", $est_count, "\tno\n" );
    };

}

$writer->close;
$log->close;

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
    #    $trans->uniquename, "\t", scalar @trans_exons, "\t",
    #    join( "\t", @texons_loc ), "\t"
    #);
    #$log->print(
    #    $repred_trans->uniquename, "\t", scalar @repred_exons, "\t",
    #    join( "\t", @rexons_loc ), "\n"
    #);
}

=head1 NAME

B<curation_targets.pl> - [Report gives a list of uncurated genes along with est count and
presence or absence of blast hit]


=head1 SYNOPSIS

=for author to fill in:
Brief code example(s) here showing commonest usage(s).
This section will be as far as many users bother reading
so make it as educational and exeplary as possible.


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

	=for author to fill in:
	Write a full description of the module and its features here.
	Use subsections (=head2, =head3) as appropriate.


=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

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



