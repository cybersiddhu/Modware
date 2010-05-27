#!/usr/bin/perl -w

use strict;
use Pod::Usage;
use Getopt::Long;
use Bio::Chado::Schema;
use Path::Class;
use IPC::Cmd qw/can_run run/;
use Cwd;
use XML::Twig::XPath;
use SQL::Translator;

my $gmod_folder;
my $output;
my $data_folder
    = Path::Class::Dir->new(getcwd)->parent->parent->subdir('data');

GetOptions(
    'h|help'     => sub { pod2usage(1); },
    'f|folder:s' => \$gmod_folder,
    'o|output:s' => \$output
);

$gmod_folder
    = $gmod_folder
    ? Path::Class::Dir->new($gmod_folder)
    : $data_folder->subdir('gmod-current');
$output
    = $output
    ? Path::Class::File->new($output)
    : $data_folder->file('chado_views.txt');

my $svn = can_run('svn') or die "svn client is not installed\n";
my $cmd
    = -e $gmod_folder->stringify
    ? [
    $svn, 'up',
    'https://gmod.svn.sourceforge.net/svnroot/gmod/schema/trunk/chado',
    $gmod_folder->stringify
    ]
    : [
    $svn, 'co',
    'https://gmod.svn.sourceforge.net/svnroot/gmod/schema/trunk/chado',
    $gmod_folder->stringify
    ];

my ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf )
    = run( command => $cmd, verbose => 1 );

if ( !$success ) {
    die "unable to run command: $stderr_buf\n";
}

my $outhandler = $output->openw;
my $twig       = XML::Twig::XPath->new->parsefile(
    $gmod_folder->file('chado-module-metadata.xml')->stringify );
my @nodes
    = $twig->findnodes(
    '//component[@type = "views" or @type = "bridge"]/source[@type = "sql"]'
    );

for my $elem (@nodes) {
    print "translating ", $elem->att('path'), "\n";
    my $reader = $gmod_folder->file('modules',  $elem->att('path') )->openr;
    while ( my $line = $reader->getline ) {
        if ( $line =~ /create\s+or\s+replace\s+view\s+(\S+)/i ) {
            $outhandler->print( $1, "\n" );
        }
    }
    $reader->close;
}

$outhandler->close;

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



