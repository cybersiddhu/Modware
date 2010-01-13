#!/usr/bin/perl -w

use strict;
use local::lib '~/dictyBase/Libs/modern-perl';
use lib '../../lib';
use Pod::Usage;
use Getopt::Long;
use Bio::Chado::Schema;
use Try::Tiny;
use YAML qw/LoadFile/;
use Log::Log4perl qw/:easy/;
use Log::Log4perl::Appender;
use Log::Log4perl::Layout::PatternLayout;
use MOD::SGD;

my ( $dsn, $user, $pass, $mdsn, $muser, $mpass, $verbose, $config );
my ( $luser, $lpass, $ldsn );
my $match_type = 'match';

GetOptions(
    'h|help'               => sub { pod2usage(1); },
    'dsn=s'                => \$dsn,
    'u|user=s'             => \$user,
    'p|pass|password=s'    => \$pass,
    'mdsn=s'               => \$mdsn,
    'ldsn=s'               => \$ldsn,
    'luser=s'              => \$luser,
    'lpass=s'              => \$lpass,
    'mu|muser=s'           => \$muser,
    'mp|mpass|mpassword=s' => \$mpass,
    'mt|match_type:s'      => \$match_type,
    'verbose'              => \$verbose,
    'c|config:s'           => \$config
);

$mdsn  = $dsn   if !$mdsn;
$ldsn  = $mdsn  if !$ldsn;
$luser = $muser if !$luser;
$lpass = $mpass if !$lpass;

if ($config) {
    my $str = LoadFile($config);
    my $db  = $str->{database};
    if ($db) {
        $dsn  = $db->{dsn}      || $dsn;
        $user = $db->{user}     || $user;
        $pass = $db->{password} || $pass;
    }
    my $meta = $str->{meta};
    if ($meta) {
        $mdsn  = $meta->{dsn}      || $mdsn;
        $muser = $meta->{user}     || $muser;
        $mpass = $meta->{password} || $mpass;
    }
    my $legacy = $str->{legacy};
    if ($legacy) {
        $ldsn  = $legacy->{dsn}      || $ldsn;
        $luser = $legacy->{user}     || $luser;
        $lpass = $legacy->{password} || $lpass;
    }
    $match_type = $str->{match_type} || $match_type;
}

pod2usage "dsn not given" if !$dsn;

my $logger = setup_logger() if $verbose;

#database connection
my $schema       = Bio::Chado::Schema->connect( $dsn,  $user,  $pass );
my $dicty_schema = Bio::Chado::Schema->connect( $mdsn, $muser, $mpass );
my $sgd_schema = MOD::SGD->connect( $ldsn, $luser, $lpass );

my $desc = $schema->resultset('Cv::Cvterm')->find( { name => 'description' } )
    ->cvterm_id;

my $hit_rs = $schema->resultset('Sequence::Feature')->search(
    { 'type.name' => $match_type, is_analysis => 1 },
    { join        => 'type',      select      => [qw/feature_id uniquename/] }
);

while ( my $hit_row = $hit_rs->next ) {
    my $gene_id  = parse_gene_id( $hit_row->uniquename );
    my $feat_row = $dicty_schema->resultset('Sequence::Feature')->search(
        {   -and => [
                'is_deleted' => 0,
                -or          => [
                    'dbxref.accession' => $gene_id,
                    'uniquename'       => $gene_id,
                    'me.name'          => $gene_id
                ]
            ]
        },
        {   join   => 'dbxref',
            select => 'feature_id',
            rows   => 1
        }
    )->single;

    if ( !$feat_row ) {
        $logger->warn( $hit_row->uniquename,
            "not found in meta source: no featureprop will be created" )
            if $verbose;
        next;
    }

    my $gp_row
        = $sgd_schema->resultset('LocusGp')
        ->search( { locus_no => $feat_row->feature_id, }, { rows => 1 } )
        ->single;
    if ( !$gp_row ) {
        $logger->warn( $hit_row->uniquename, " no gene product name" )
            if $verbose;
        next;
    }

    #lets check if that particular featureprop is present
    my $prop_rs
        = $hit_row->featureprops->search( { 'type.name' => 'description' },
        { join => 'type' } );
    if ( $prop_rs->count > 0 ) {
        $logger->warn( $hit_row->uniquename,
            " already has a featureprop : not overwritten" )
            if $verbose;
        next;
    }

    try {
        $schema->txn_do(
            sub {
                $hit_row->create_related(
                    'featureprops',
                    {   value   => $gp_row->locus_gene_product->gene_product,
                        type_id => $desc
                    },
                );
            }
        );
        $logger->info( "created featureprop for ", $hit_row->uniquename )
            if $verbose;
    }
    catch {
        $logger->error("cannot create featureprop $_") if $verbose;

    };

}

sub parse_gene_id {
    my ($str) = @_;
    my $label = ( ( split /:/,  $str ) )[0];
    $label;
}

sub setup_file_logger {
    my $appender
        = Log::Log4perl::Appender->new( 'Log::Log4perl::Appender::File',
        filename => 'load_alignment.log' );

    my $layout = Log::Log4perl::Layout::PatternLayout->new(
        "[%d{MM-dd-yyyy hh:mm}] %p > %F{1}:%L - %m%n");

    my $log = Log::Log4perl->get_logger();
    $appender->layout($layout);
    $log->add_appender($appender);
    $log->level($DEBUG);
    $log;
}

sub setup_logger {
    my $appender
        = Log::Log4perl::Appender->new(
        'Log::Log4perl::Appender::ScreenColoredLevels',
        stderr => 1 );

    my $layout = Log::Log4perl::Layout::PatternLayout->new(
        "[%d{MM-dd-yyyy hh:mm}] %p > %F{1}:%L - %m%n");

    my $log = Log::Log4perl->get_logger();
    $appender->layout($layout);
    $log->add_appender($appender);
    $log->level($DEBUG);
    $log;
}

=head1 NAME

    B <Application name> - [ One line description of application purpose ]

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



