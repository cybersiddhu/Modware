#!/usr/bin/perl -w

use strict;
use Pod::Usage;
use Getopt::Long;
use Bio::SearchIO;
use Bio::Chado::Schema;
use Try::Tiny;

my ( $dsn, $user, $pass, $query_type, $update, $query_org, $target_org );
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
    'opt|dbopt:s'        => \$option,
    'so|seq_onto:s'      => \$seq_onto,
    'mt|match_type:s'    => \$match_type,
);

my $schema = Bio::Chado::Schema->connect( $dsn, $user, $pass, $option );

#$schema->storage->debug(1);

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
        $rs->search_related('dbxref')->delete_all;
        $rs->delete_all;
    }
    $orphan_hit_rs->search_related('dbxref')->delete_all;
    $orphan_hit_rs->delete_all;
};

try {
    $schema->txn_do($delete_alignment);
}
catch {
    warn "Alignment cannot be deleted $_\n";
}


=head1 NAME

B<prune_alignment.pl> - [Delete all blast alignments from chado database]


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



