#!/usr/bin/perl -w

use strict;
use Pod::Usage;
use Getopt::Long;
use FindBin qw/$Bin/;
use lib ( "$Bin/../../lib", "$ENV{HOME}/dictyBase/Libs/dictylegacy/lib" );
use dicty::Legacy::Search::Reference;
use Path::Class;
use aliased 'Modware::Publication';
use aliased 'Modware::Publication::JournalArticle';
use aliased 'Modware::DataSource::Chado';
use aliased 'Modware::Publication::Author';
use Carp::Always;

my $file = Path::Class::Dir->new($Bin)->parent->parent->subdir('data')
    ->file('pub_dump.txt')->openw;
my $not_loaded = Path::Class::Dir->new($Bin)->parent->parent->subdir('data')
    ->file('pub_not_loaded.txt')->openw;
my ( $dsn, $user, $pass );
GetOptions(
    'h|help'            => sub { pod2usage(1); },
    'dsn=s'             => \$dsn,
    'u|user:s'          => \$user,
    'p|pass|password:s' => \$pass
);

die "no dsn given\n" if !$dsn;

my $attr = $dsn =~ /Oracle/i ? { LongTruncOk => 1 } : {};

Chado->connect(
    dsn      => $dsn,
    user     => $user,
    password => $pass,
    attr     => $attr
);

my $count = 0;
my $limit = $ARGV[0] || 10;
print "journal to be loaded: $limit\n";

my $itr = dicty::Legacy::Search::Reference->Search_all($limit);
REFERENCE:
while ( my $ref = $itr->next ) {
    my $pub;
    if ( $ref->pmid ) {
        $pub = Publication->new( pubmed_id => $ref->pmid );
        if ( $ref->can('medline') && $ref->medline ) {
            $file->print( "medline: ", $ref->medline, "\n" );
            $pub->medline_id( $ref->medline );
        }
    }
    else {
        $pub = JournalArticle->new;
    }

    for my $method (qw/year source status title issue volume/) {
        if ( $ref->$method ) {
            $pub->$method( $ref->$method );
            $file->print( $method . ': ', $ref->$method, "\n" );
        }
    }

    if ( $ref->page ) {
        my ( $first_page, $last_page ) = split /\-/, $ref->page;
        $pub->first_page($first_page);
        $pub->last_page($last_page);
    }
    $pub->type('journal_article') if $ref->type eq 'Journal Article';

    if ( $ref->can('journal_abbr') ) {
        $file->print( "journal: ", $ref->journal_abbr, "\n" );
        $pub->journal( $ref->journal_abbr );
        $pub->abbreviation( $ref->journal_abbr );
    }
    else {
        $not_loaded->print( $ref->reference_no, "\n" );
        next REFERENCE;
    }

    if ( $ref->abstract ) {
        $file->print( "Abstract\n ----- \n",
            $ref->abstract, "\n-------------\n\n" );
        $pub->abstract( $ref->abstract );
    }

    for my $name ( @{ $ref->authors } ) {
        if ( $name =~ /^([^,.]+)(.+)$/ ) {
            my $first_name = $1;
            my $last_name  = $2;
            $last_name =~ s/\,//;
            $last_name =~ s/^s+//;
            $pub->add_author(
                Author->new(
                    first_name => $first_name,
                    last_name  => $last_name
                )
            );
            $file->print("Authors :: $first_name\t$last_name\n");
        }
    }

    for my $word ( @{ $ref->topics } ) {
        $pub->add_keyword($word);
        $file->print( "topic: ", $word, "\n" );
    }
    if ( $ref->not_curated ) {
        $pub->add_keyword('Not yet curated');
        $file->print("topic: Not yet curated\n");
    }

    $pub->create;
    $count++;

    $file->print( "Short Citation :: ", $ref->short_citation, "\n" );
    $file->print( "Citation :: ",       $ref->writeCitation,  "\n" );
    $file->print( "CitationAuthString :: ",
        $ref->writeCitationAuthorString, "\n" );
    $file->print( "Formatted Citation :: ", $ref->formatted_citation, "\n" );
    $file->print("\n =========== \n");
}

print "journal loaded: $count\n";
$file->close;
$not_loaded->close;

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



