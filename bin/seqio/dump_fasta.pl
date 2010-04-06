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

my $option = { LongReadLen => 2**25 };
my $schema = Bio::Chado::Schema->connect( $dsn, $user, $pass, $option );

while ( my $line = $reader->getline ) {
    chomp $line;

    #Assuming it is gene id get the gene object
    my $gene = $schema->resultset('Sequence::Feature')
        ->find( { 'dbxref.accession' => $line }, { join => 'dbxref' } );

    #now to the transcript
    my $trans_rs = $gene->search_related(
        'feature_relationship_objects',
        { 'type.name' => 'part_of' },
        { join        => 'type' }
        )->search_related(
        'subject',
        { 'type_2.name' => 'mRNA' },
        { join          => 'type', row => 1 }
        )->single;

    print $gene->name, "\t", $trans_rs->name, "\n";

}

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



