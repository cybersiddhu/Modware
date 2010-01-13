#!/usr/bin/perl -w

use strict;
use local::lib '~/modern-perl';
use Pod::Usage;
use Getopt::Long;
use Bio::Chado::Schema;
use YAML qw/LoadFile/;

my ( $dsn, $user, $pass, $config, $debug, $sql_debug );
my $seq_onto = 'sequence';
my $option = { LongReadLen => 2**15 };

GetOptions(
    'h|help'            => sub { pod2usage(1); },
    'dsn=s'             => \$dsn,
    'u|user=s'          => \$user,
    'p|pass|password=s' => \$pass,
    'opt|dbopt:s'       => \$option,
    'c|config:s'        => \$config,
);

if ($config) {
    my $str = LoadFile($config);
    my $db  = $str->{database};
    if ($db) {
        $dsn  = $db->{dsn}      || $dsn;
        $user = $db->{user}     || $user;
        $pass = $db->{password} || $pass;
    }
}

pod2usage "no id given for search" if !$ARGV[0];

my $schema = Bio::Chado::Schema->connect( $dsn, $user, $pass );
$schema->storage->debug(1);

my $query_row = $schema->resultset('Sequence::Feature')->search(
    {   -and => [
            'is_deleted'  => 0,
            'is_analysis' => 1,
            -or           => [
                'dbxref.accession' => $ARGV[0],
                'uniquename'       => $ARGV[0],
                'name'             => $ARGV[0]
            ]
        ]
    },
    {   join   => 'dbxref',
        select => [qw/feature_id type_id uniquename name/],
        rows   => 1
    }
)->single;

die "query $ARGV[0] not found in database\n" if !$query_row;

#get all HSPs
my $hsp_rs
    = $query_row->search_related( 'featureloc_srcfeature_ids',
    { 'rank' => 1 } )->search_related(
    'feature',
    {   'type.name'           => 'match_part',
        'type.cv_id'          => $query_row->type->cv_id,
        'feature.is_analysis' => 1,
    },
    { join => 'type' }
    );
if ( $hsp_rs->count == 0 ) {
    die "No hsps for $ARGV[0]\n";
}

my $hit_rs = $schema->resultset('Sequence::Feature')->search(
    {   'type.name'    => 'protein_match',
        'type_2.name'  => 'part_of',
        'type_2.cv_id' => $query_row->type->cv_id,
        'subject.feature_id' =>
            { -in => [ map { $_->feature_id } $hsp_rs->all ] }
    },
    {   join => [
            'type',
            { 'feat_relationship_object_ids' => [ 'type', 'subject' ] }
        ]
    }
);

print "Hit and HSP for query $ARGV[0]\n";
print "==============================\n\n";

print "No of hit: ", $hit_rs->count, "\n";

while ( my $row = $hit_rs->next ) {
    print ' hit : ', $row->name, "\n";
}

print ' No of hsps : ', $hsp_rs->count, "\n";
while ( my $row = $hsp_rs->next ) {
    print ' hsp : ', $row->name, "\n";
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


perl load_alignment.pl -c config.yaml


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

B<[-c|-config]> - Configuration in YAML format from where options will be read. Here is an
example of it .....


=over


#The main datasource where the blast alignment will be stored 
database:
  dsn: "dbi:Oracle:host=yada;sid=yada"
  user: yada
  password: yada

#The database from where the hit id will be looked up 
 #Absolutely dictybase specific
meta:
  dsn: "dbi:Oracle:host=yada;sid=yada"
  user: yada
  password: yada

#Where the gene product name is stored
 #Absolutely dictybase specific
legacy:
  dsn: "dbi:Oracle:host=yada;sid=yada"
  user: yada
  password: yada

query:
  organism: dicty
  parser: dicty

target:
  parser: none
  organism: dpur

so: sequence

source: dictyBase_blast

database_source : GFF_source

match_type: protein_match


=back


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


