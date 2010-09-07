#!/usr/bin/perl -w

use strict;
use Pod::Usage;
use Getopt::Long;
use Bio::Chado::Schema;
use DBIx::Class::Fixtures;
use Cwd;
use Path::Class;

my $config_file = 'pub.json';
GetOptions(
    'h|help'      => sub { pod2usage(1); },
    'f|fixture:s' => \$config_file
);

die "no sqlite file name given\n" if !$ARGV[0];
my $data_dir = Path::Class::Dir->new(getcwd)->parent->parent->subdir('data');
my $config_dir  = $data_dir->subdir('config');
my $fixture_dir = $data_dir->subdir('fixture');

my $schema
    = Bio::Chado::Schema->connect( "dbi:SQLite:dbname=$ARGV[0]", '', '' );
my $fixture
    = DBIx::Class::Fixtures->new( { config_dir => $config_dir->stringify } );

$fixture->dump(
    {   config    => $config_file,
        schema    => $schema,
        directory => $fixture_dir->stringify
    }
);

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



