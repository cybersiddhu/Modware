#!/usr/bin/perl -w

use strict;
use Pod::Usage;
use Getopt::Long;
use FindBin qw/$Bin/;
use lib ( "$Bin/../../lib", "$ENV{HOME}/dictyBase/Libs/dictylegacy/lib" );
use dicty::Legacy::Search::Reference;
use Path::Class;
use Modware::Publication::DictyBase;
use aliased 'Modware::DataSource::Chado';
use aliased 'Modware::Publication::Author';

my $file = Path::Class::Dir->new($Bin)->parent->parent->subdir('data')
    ->file('pub_dump.txt')->openw;
my $not_loaded = Path::Class::Dir->new($Bin)->parent->parent->subdir('data')
    ->file('pub_not_loaded.txt')->openw;
my ( $dsn, $user, $pass );
my $delete           = 1;
my $commit_threshold = 1000;

GetOptions(
    'h|help'            => sub { pod2usage(1); },
    'dsn=s'             => \$dsn,
    'u|user:s'          => \$user,
    'p|pass|password:s' => \$pass,
    't|threshold:s'     => \$commit_threshold,
    'delete!'           => \$delete
);

die "no dsn given\n" if !$dsn;

my $attr
    = $dsn =~ /Oracle/i
    ? { LongTruncOk => 1, AutoCommit => 1 }
    : { AutoCommit => 1 };

Chado->connect(
    dsn      => $dsn,
    user     => $user,
    password => $pass,
    attr     => $attr
);

my $schema = Chado->handler;
my $rs     = $schema->resultset('Pub::Pub');

if ($delete) {
    $schema->txn_do(
        sub {
            $rs->delete_all;
        }
    );
}

my $count = 0;
my $limit = $ARGV[0] || 'all';
print "journal to be loaded: $limit\n";

my $itr
    = $limit eq 'all'
    ? dicty::Legacy::Search::Reference->Search_all()
    : dicty::Legacy::Search::Reference->Search_all($limit);

my $cache;
REFERENCE:
while ( my $ref = $itr->next ) {
    my $pub = Modware::Publication::DictyBase->new(
        id => 'PUB' . $ref->reference_no );
    $file->print( "id: ", $ref->reference_no, "\n" );

    $pub->type( lc $ref->type );
    $file->print( 'type: ', $ref->type, "\n" );

    if ( $ref->pmid ) {
        $pub->pubmed_id( $ref->pmid );
        $file->print( "pubmed: ", $ref->pmid, "\n" );
        if ( $ref->can('medline') && $ref->medline ) {
            $pub->medline_id( $ref->medline );
            $file->print( "medline: ", $ref->medline, "\n" );
        }
    }

    if ( $ref->can('journal_abbr') ) {
        $pub->journal( $ref->journal_abbr );
        $pub->abbreviation( $ref->journal_abbr );
        $file->print( "journal: ", $ref->journal_abbr, "\n" );
    }

    $pub->full_text_url( $ref->full_text_url ) if $ref->full_text_url;

    for my $method (qw/year source status title issue volume/) {
        if ( $ref->$method ) {
            $pub->$method( $ref->$method );
            $file->print( $method . ': ', $ref->$method, "\n" );
        }
    }

    if ( $ref->page ) {
        my ( $first_page, $last_page ) = split /\-/, $ref->page;
        $pub->first_page($first_page) if $first_page;
        $pub->last_page($last_page)   if $last_page;
        $file->print( 'page: ', $ref->page, "\n" );
    }

    if ( $ref->abstract ) {
        $pub->abstract( $ref->abstract );
        $file->print( "Abstract\n ----- \n",
            $ref->abstract, "\n-------------\n\n" );
    }

    my @authors = @{ $ref->authors };
    if ( !@authors ) {
        $not_loaded->print( $ref->reference_no, "\tno author\n" );
        undef $pub;
        next REFERENCE;
    }

    for my $name (@authors) {
        if ( $name =~ /^(\w+)$/ ) {
            $pub->add_author( Author->new( last_name => $1, ) );
            $file->print("Author unorthodox :: $name\t$1\n");
        }
        elsif ( $name =~ /^([^,.]+)(.+)$/ ) {
            my $first_name = $2;
            my $last_name  = $1;
            $first_name =~ s/\,//;
            $first_name =~ s/^s+//;
            $pub->add_author(
                Author->new(
                    first_name => $first_name,
                    last_name  => $last_name
                )
            );
            $file->print(
                "Authors regular :: $name\t$first_name\t$last_name\n");
        }
        else {
            $not_loaded->print( $ref->reference_no,
                ": $name\tno author parsed\n" );
            next REFERENCE;
        }
    }

    for my $word ( @{ $ref->topics } ) {
        $pub->add_keyword($word);
        $file->print( "topic: ", $word, "\n" );
    }

    $file->print("\n==== Done ======= \n");

    push @$cache, $pub->inflate_to_hashref;
    if ( @$cache >= $commit_threshold ) {
        print "start commiting\n";
        $rs->populate($cache);
        print "commited $commit_threshold entries\n";
        $count += $commit_threshold;
        undef $cache;
    }
}

if ( defined @$cache ) {
    print "commiting rest of the entries\n";
    $rs->populate($cache);
    print "done\n";
    $count += scalar @$cache;
}

print "loaded $count entries\n";
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



