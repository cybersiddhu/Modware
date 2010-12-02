
#!/usr/bin/perl -w

use strict;
use Pod::Usage;
use Getopt::Long;
use YAML qw/LoadFile/;
use Bio::Chado::Schema;
use Data::Dumper::Concise;
use Carp;

{

    package Logger;
    use Log::Log4perl;
    use Log::Log4perl::Appender;
    use Log::Log4perl::Level;

    sub handler {
        my ( $class, $file ) = @_;

        my $appender;
        if ($file) {
            my $appender = Log::Log4perl::Appender->new(
                'Log::Log4perl::Appender::File',
                filename => $file,
                mode     => 'clobber'
            );
        }
        else {
            $appender
                = Log::Log4perl::Appender->new(
                'Log::Log4perl::Appender::ScreenColoredLevels',
                );
        }

        my $layout = Log::Log4perl::Layout::PatternLayout->new(
            "[%d{MM-dd-yyyy hh:mm}] %p > %F{1}:%L - %m%n");

        my $log = Log::Log4perl->get_logger();
        $appender->layout($layout);
        $log->add_appender($appender);
        $log->level($DEBUG);
        $log;
    }

}

my ( $dsn, $user, $password, $config, $log_file, $logger );
my $no_cascade;
my $attr = { AutoCommit => 1 };

GetOptions(
    'h|help'            => sub { pod2usage(1); },
    'u|user:s'          => \$user,
    'p|pass|password:s' => \$password,
    'dsn:s'             => \$dsn,
    'c|config:s'        => \$config,
    'l|log:s'           => \$log_file,
    'a|attr:s%{1,}'     => \$attr,
    'force_cascade'        => \$no_cascade
);

pod2usage("!! namespace is not given !!") if !$ARGV[0];

if ($config) {
    my $str = LoadFile($config);
    pod2usage("given config file $config do not have database section")
        if not defined $str->{database};

    pod2usage("given config file $config do not have dsn section")
        if not defined $str->{database}->{dsn};

    $dsn      = $str->{database}->{dsn};
    $user     = $str->{database}->{dsn} || undef;
    $password = $str->{database}->{dsn} || undef;
    $attr     = $str->{database}->{attr} || $attr;
    $logger = $str->{log} ? Logger->handler( $str->{log} ) : Logger->handler;

}
else {
    pod2usage("!!! dsn option is missing !!!") if !$dsn;
    $logger = $log_file ? Logger->handler($log_file) : Logger->handler;
}

my $schema = Bio::Chado::Schema->connect( $dsn, $user, $password, $attr );

my $cv_rs = $schema->resultset('Cv::Cv')->search( { 'me.name' => $ARGV[0] } );
$logger->logdie("namespace $ARGV[0] do not exist !!!!") if !$cv_rs->count;

$logger->info("dropping ontology $ARGV[0] ....");
my $cvterm_rs = $cv_rs->search_related( 'cvterms', {} );
my $dbxref_ids = [
    map { $_->dbxref_id } (
        $cvterm_rs->all,
        $cvterm_rs->search_related( 'cvterm_dbxrefs', {} )->all
    )
];
my $dbxref_rs = $schema->resultset('General::Dbxref')
    ->search( { dbxref_id => { -in => $dbxref_ids } } );
$schema->txn_do(
    sub {
    	if ($no_cascade) {
    	  $cvterm_rs->search_related('cvterm_dbxrefs',  {})->delete_all;	
    	  $cvterm_rs->search_related('cvtermprop_cvterms',  {})->delete_all;	
    	  $cvterm_rs->search_related('cvterm_relationship_subjects',  {})->delete_all;	
    	  $cvterm_rs->search_related('cvterm_relationship_objects',  {})->delete_all;	
    	  if ($schema->storage->sqlt_type eq 'Oracle') {
    	  	my @cvterm_ids = map {$_->cvterm_id} $cvterm_rs->all;
    	  	$schema->storage->dbh_do(
    	  		sub {
    	  			my ($storage, $dbh,  @ids) = @_;
    	  	        return if !@ids;
    	  			my $values = join(', ', @ids);
    	  			$dbh->do("DELETE FROM cvtermsynonym where cvterm_id IN ($values)");
    	  		},  @cvterm_ids
    	  	);
    	  }
    	  $cvterm_rs->delete_all;
    	}
        $cv_rs->delete_all;
        $dbxref_rs->delete_all;
        $logger->info("dropped ontology $ARGV[0]");
    }
);

=head1 NAME


B<drop_ontology.pl> - [Drop ontology from chado database]


=head1 SYNOPSIS

perl drop_ontology [options] <namespace>

perl drop_ontology --dsn "dbi:Pg:dbname=gmod" -u tucker -p halo sequence

perl drop_ontology --dsn "dbi:Oracle:sid=modbase" -u tucker -p halo -a AutoCommit=1 LongTruncOk=1 go

perl drop_ontology -c config.yaml -l output.txt relation


=head1 REQUIRED ARGUMENTS

namespace                 ontology namespace

=head1 OPTIONS

-h,--help                display this documentation.

--dsn                    dsn of the chado database

-u,--user                chado database user name

-p,--pass,--password     chado database password 

-l,--log                 log file for writing output,  otherwise would go to STDOUT 

-a,--attr                Additonal attribute(s) for database connection passed in key value pair 

--force_cascade          Run separate delete on all dependent table,  do not depend on
                         database cascade,  by default is off. 

-c,--config              yaml config file,  if given would take preference

=head2 Yaml config file format

database:
  dsn:'....'
  user:'...'
  password:'.....'
  attr: '.....'
log: '...'



=head1 DESCRIPTION


=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

YAML

Bio::Chado::Schema

=head1 BUGS AND LIMITATIONS

No bugs have been reported.Please report any bugs or feature requests to

B<Siddhartha Basu>


=head1 AUTHOR

I<Siddhartha Basu>  B<siddhartha-basu@northwestern.edu>

=head1 LICENCE AND COPYRIGHT

Copyright (c) B<2010>, Siddhartha Basu C<<siddhartha-basu@northwestern.edu>>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.



