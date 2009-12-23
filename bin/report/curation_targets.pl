#!/usr/bin/perl -w

use strict;
use Pod::Usage;
use Getopt::Long;
use Bio::Chado::Schema;
use Bio::Index::Blast;
use List::MoreUtils qw/any/;
use IO::File;
use Try::Tiny;
use autodie;

my ( $dsn, $user, $pass, $idx );
my $out = 'curator_report.txt';

GetOptions(
    'h|help'            => sub { pod2usage(1) },
    'dsn=s'             => \$dsn,
    'u|user=s'          => \$user,
    'p|pass|password=s' => \$pass,
    'idx|index=s'       => \$idx,
    'o|out|output:s'    => \$out,
);

pod2usage("no blast index file name given") if !$idx;

my $writer = IO::File->new( $out, 'w' );
my $blast = Bio::Index::Blast->new( -filename => $idx );
my $option = { LongReadLen => 2**25 };
my $schema = Bio::Chado::Schema->connect( $dsn, $user, $pass, $option );

my $gene_rs = $schema->resultset('Sequence::Feature')->search(
    { 'type.name' => 'gene', },
    {   join     => [qw/type dbxref featureloc_feature_ids/],
        prefetch => [qw/dbxref/],
        rows     => 1000,
    }
);

GENE:
while ( my $gene = $gene_rs->next ) {
    my $trans_rs = $gene->feat_relationship_object_ids->search_related(
        'subject',
        { 'type.name' => 'mRNA' },
        { join        => 'type', },
    );

    #checking for curated model
    while ( my $trans = $trans_rs->next ) {
        if ( any { $_->accession =~ /Curator/i } $trans->secondary_dbxrefs ) {
            next GENE;
        }
    }

    my $floc_row = $gene->featureloc_feature_ids->single;
    my $start    = $floc_row->fmin;
    my $end      = $floc_row->fmax;
    my $src_id   = $floc_row->srcfeature_id;

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

    my $est_rs = $schema->resultset('Sequence::Feature')
        ->search( $where, { join => [qw/featureloc_feature_ids type/] } );

    my $gene_id = $gene->dbxref->accession;

    #blast hit lookup
    my $result;
    try {
        $result = $blast->fetch_report($gene_id);
    }
    catch {
        warn $_;
        print $gene_id, "\t", $est_rs->count, "\tno\n";
        $writer->print( $gene_id, "\t", $est_rs->count, "\tno\n" );
        next GENE;
    };

    #no result or no hit
    if ( !$result or $result->num_hits == 0 ) {
        print $gene_id, "\t", $est_rs->count, "\tno\n";
        $writer->print( $gene_id, "\t", $est_rs->count, "\tno\n" );
        next GENE;
    }

    print $gene_id, "\t", $est_rs->count, "\tyes\n";
    $writer->print( $gene_id, "\t", $est_rs->count, "\tyes\n" );
}

$writer->close;

=head1 NAME

B<Application name> - [One line description of application purpose]


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



