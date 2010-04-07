#!/usr/bin/perl -w

use strict;
use Pod::Usage;
use Bio::Chado::Schema;
use autodie;
use FindBin qw/$Bin/;
use YAML qw/LoadFile/;
use Time::Piece;
use Path::Class;
use Getopt::Long;

my $t = Time::Piece->new;
my $conf_file
    = Path::Class::Dir->new($Bin)->parent->parent->subdir( 'data', 'config' )
    ->file('sequence.yaml')->stringify;
my $logfile = Path::Class::Dir->new($Bin)->parent->parent->subdir('log')
    ->file( 'fasta_dump' . $t->mdy . '.log' )->stringify;

my $output;

GetOptions(
    'h|help'         => sub { pod2usage(1); },
    'c|config:s'     => \$conf_file,
    'o|out|output:s' => \$output
);

pod2usage(
    "!!!! configuration file is not found: report to the author of this script"
) if !-e $conf_file;

#Getting values from config file if not set from command line

# -- output file
my $config = LoadFile($conf_file);
$output = $config->{output} if !$output and defined $config->{output};
pod2usage("no output file given") if !$output;
my $writer = Path::Class::File->new($output)->openw;

# -- input file
my $input = $ARGV[0];
$input = $config->{input} if !$input and defined $config->{input};
pod2usage("no output file given") if !$input;
my $reader = Path::Class::File->new($input)->openr;

# -- db setup
my $db_config = $config->{database};
my $dsn       = $db_config->{dsn};
my $user      = $db_config->{user};
my $pass      = $db_config->{pass};

# -- logger
my $log = MyLogger->file_logger($logfile);

my $option = { LongReadLen => 2**25 };
my $schema = Bio::Chado::Schema->connect( $dsn, $user, $pass, $option );

GENE:
while ( my $line = $reader->getline ) {
    chomp $line;

    #Assuming it is gene id get the gene object
    my $gene = $schema->resultset('Sequence::Feature')
        ->find( { 'dbxref.accession' => $line }, { join => 'dbxref' } );

    my $name = $gene->name;
    if ( $name =~ /_ps\S{0,}$/ ) {
        $log->warn("skipped gene $name");
        next GENE;
    }

    #now to the transcript
    my $trans_rs = $gene->search_related(
        'feature_relationship_objects',
        { 'type.name' => 'part_of' },
        { join        => 'type' }
        )->search_related(
        'subject',
        { 'type_2.name' => 'mRNA' },
        { join          => 'type' }
        );

    my $count = $trans_rs->count;
    if ( $count == 0 or $count > 1 ) {
        warn "issue with gene $line\n";
        $log->warn("issue with gene $line:$name");
        next GENE;
    }

    my $poly_rs = $trans_rs->first->search_related(
        'feature_relationship_objects',
        { 'type.name' => 'derived_from' },
        { join        => 'type' }
        )->search_related(
        'subject',
        { 'type_2.name' => 'polypeptide' },
        { join          => 'type' }
        );

    if ( $poly_rs->count == 0 ) {
        warn "no polypeptide found for $line:$name\n";
        $log->warn("no polypeptide found for $line:$name");
        next GENE;
    }

    my $seq = $poly_rs->first->residues;
    $seq =~ s/(\S{1,60})/$1\n/g;
    $writer->print(">$name\n$seq");

    $log->info("wrote fasta sequence for $line:$name");
}

$reader->close;
$writer->close;

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

	Copyright (c) B<2010>, Siddhartha Basu C<<siddhartha-basu@northwestern.edu>>. All rights reserved.

	This module is free software; you can redistribute it and/or
	modify it under the same terms as Perl itself. See L<perlartistic>.



