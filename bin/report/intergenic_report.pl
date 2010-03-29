#!/usr/bin/perl -w

use strict;
use local::lib '~/dictyBase/Libs/modern-perl';
use Pod::Usage;
use Data::Dumper;
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
    ->file('prune.yaml')->stringify;
pod2usage(
    "!!!! configuration file is not found: report to the author of this script"
) if !-e $conf_file;

my $config = LoadFile($conf_file);

my $db_config = $config->{database};
my $dsn       = $db_config->{dsn};
my $user      = $db_config->{user};
my $pass      = $db_config->{password};

my $t = localtime;
my $outfolder
    = Path::Class::Dir->new($Bin)->parent->parent->subdir( 'data', 'report' );

my $logfile = Path::Class::Dir->new($Bin)->parent->parent->subdir('log')
    ->file( 'intergenic_log_' . $t->mdy . '.txt' )->stringify;
my $log = MyLogger->file_logger($logfile);

my $option = { LongReadLen => 2**25 };
my $schema = Bio::Chado::Schema->connect( $dsn, $user, $pass, $option );
my $DBH    = $schema->storage->dbh;
my $FLAG   = 0;

my $contig_rs
    = $schema->resultset('Sequence::Feature')
    ->search( { 'type.name' => 'supercontig' },
    { join => 'type', order_by => { -desc => 'me.name' } } );

SUPERCONTIG:
while ( my $contig = $contig_rs->next ) {
    my $gene_rs
        = $contig->search_related( 'featureloc_srcfeature_ids', {}, )
        ->search_related(
        'feature',
        { 'type.name' => 'gene' },
        {   join     => [ 'type', 'featureloc_feature_ids' ],
            order_by => { -asc    => 'featureloc_feature_ids.fmin' }
        }
        );

    next SUPERCONTIG if $gene_rs->count == 0;
    my $ordered;
    while ( my $gene = $gene_rs->next ) {
        push @$ordered,
            {
            start  => $gene->featureloc_feature_ids->first->fmin + 1,
            end    => $gene->featureloc_feature_ids->first->fmax,
            strand => $gene->featureloc_feature_ids->first->strand,
            id     => $gene->dbxref->accession
            };
    }
    $log->debug( Dumper $ordered);
    report_intergenic(
        segment => $contig,
        genes   => $ordered,
        path    => $outfolder
    );
}

sub write_fasta {
    my %arg      = @_;
    my $sequence = $arg{sequence};
    my $length   = length $sequence;
    if ( $length < 100 ) {
        $arg{writer}->print(">$arg{id}|$arg{strand}|flag\n");
    }
    else {
        $arg{writer}->print(">$arg{id}|$arg{strand}\n");
    }

    if ( $length <= 60 ) {
        $arg{writer}->print( $sequence, "\n" );
    }
    else {
        $sequence =~ s/([ATGCN]{1,60})/$1\n/g;
        $arg{writer}->print( $sequence);

    }
}

sub report_intergenic {
    my %arg   = @_;
    my $genes = $arg{genes};
    my $output
        = $arg{path}->file( $arg{segment}->name . '_intergenic.fa' )->openw;

    #with only one gene
    if ( $#$genes == 0 ) {
        my $seq;
        if ( $genes->[0]->{strand} == -1 ) {
            $seq = revcom(
                fetch_sequence(
                    segment => $arg{segment},
                    start   => $genes->[0]->{end},
                    end     => $arg{segment}->seqlen + 1,
                    id      => $genes->[0]->{id}
                )
            );
        }
        else {
            $seq = fetch_sequence(
                segment => $arg{segment},
                end     => $genes->[0]->{start},
                id      => $genes->[0]->{id},
                start   => 1
            );
        }

        write_fasta(
            id       => $genes->[0]->{id},
            strand   => $genes->[0]->{strand},
            sequence => $seq,
            writer   => $output
        ) if $seq;

        return;
    }

    for my $i ( 0 .. $#$genes ) {
        my $sequence;
        my $strand = $genes->[$i]->{strand};

        #first gene
        if ( $i == 0 ) {
            if ( $genes->[$i]->{strand} == -1 ) {
                $sequence = revcom(
                    fetch_sequence(
                        segment => $arg{segment},
                        start   => $genes->[$i]->{end},
                        end     => $genes->[ $i + 1 ]->{start},
                        id      => $genes->[$i]->{id}
                    )
                );
            }
            else {
                $sequence = fetch_sequence(
                    segment => $arg{segment},
                    end     => $genes->[$i]->{start},
                    id      => $genes->[$i]->{id},
                    start   => 1
                );
            }
            if ($sequence) {
                write_fasta(
                    id       => $genes->[$i]->{id},
                    strand   => $genes->[$i]->{strand},
                    sequence => $sequence,
                    writer   => $output
                );
            }
            next;
        }

        #last gene
        if ( $i == $#$genes ) {
            if ( $genes->[$i]->{strand} == -1 ) {
                $sequence = revcom(
                    fetch_sequence(
                        segment => $arg{segment},
                        start   => $genes->[$i]->{end},
                        end     => $arg{segment}->seqlen + 1,
                        id      => $genes->[$i]->{id}
                    )
                );
            }
            else {
                $sequence = fetch_sequence(
                    segment => $arg{segment},
                    start   => $genes->[ $i - 1 ]->{end},
                    end     => $genes->[$i]->{start},
                    id      => $genes->[$i]->{id}
                );
            }
            if ($sequence) {
                write_fasta(
                    id       => $genes->[$i]->{id},
                    strand   => $genes->[$i]->{strand},
                    sequence => $sequence,
                    writer   => $output
                );
            }
            last;
        }

        #rest of them
        if ( $genes->[$i]->{strand} == -1 ) {
            $sequence = revcom(
                fetch_sequence(
                    segment => $arg{segment},
                    start   => $genes->[$i]->{end},
                    end     => $genes->[ $i + 1 ]->{start},
                    id      => $genes->[$i]->{id}
                )
            );
        }
        else {
            $sequence = fetch_sequence(
                segment => $arg{segment},
                start   => $genes->[ $i - 1 ]->{end},
                end     => $genes->[$i]->{start},
                id      => $genes->[$i]->{id}
            );
        }
        if ($sequence) {
            write_fasta(
                id       => $genes->[$i]->{id},
                strand   => $genes->[$i]->{strand},
                sequence => $sequence,
                writer   => $output
            );
        }
    }
    $output->close;
}

sub revcom {
    my $str     = shift;
    my $reverse = reverse $str;
    $reverse =~ tr/ATGC/TACG/;
    $reverse;
}

sub fetch_sequence {
    my %arg    = @_;
    my $start  = $arg{start};
    my $length = $arg{end} - $arg{start};

    my ($seq) = $DBH->selectrow_array(
        "SELECT substr(residues, $start ,  $length) from
	feature where uniquename = ?", undef, ( $arg{segment}->uniquename )
    );
    if ( !$seq ) {
        $log->warn(
            "no sequence for gene: $arg{id} with $arg{start} and $arg{end}");
        return;
    }
    $seq;
}

package MyLogger;

use Log::Log4perl qw/:easy/;
use Log::Log4perl::Appender;
use Log::Log4perl::Layout::PatternLayout;

sub file_logger {
    my ( $class, $file ) = @_;
    my $appender = Log::Log4perl::Appender->new(
        'Log::Log4perl::Appender::File',
        filename => $file,
        mode     => 'clobber'
    );

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
If all of the application's arguments are optional,
                this section may be omitted entirely .

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



