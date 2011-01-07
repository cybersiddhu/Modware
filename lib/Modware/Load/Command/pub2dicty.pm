package Modware::Load::Command::pub2dicty;
use strict;

# Other modules:
use namespace::autoclean;
use Moose;
use Email::Valid;
use Moose::Util::TypeConstraints;
use File::Find::Rule;
use File::stat;
use Bio::Biblio::IO;
use Modware::DataSource::Chado;
use Modware::Publication::DictyBase;
use Try::Tiny;
use Carp;
extends qw/Modware::Load::Command/;
with 'Modware::Role::Command::WithEmail';

# Module implementation
#

subtype 'Email' => as 'Str' => where { Email::Valid->address($_) };

has 'source' => (
    is            => 'rw',
    isa           => 'Str',
    default       => 'PUBMED',
    documentation => 'Primary source of the publication,  default is PUBMED'
);

has 'type' => (
    is            => 'rw',
    isa           => 'Str',
    default       => 'journal article',
    documentation => 'The type of publication,  default is * journal article *'
);

has 'email' => (
    is      => 'rw',
    isa     => 'Email',
    default => 'dictybase@northwestern.edu',
    documentation =>
        'e-mail that will be passed to eutils,  default is * dictybase@northwestern.edu *'
);

has '+input' => (
    documentation =>
        'pubmedxml format file,  default is to pick up the latest from data dir,  file name that matches pubmed_[datestring].xml',
    default => sub {
        my $self = shift;
        my @files = map { $_->[1] }
            sort { $b->[0] <=> $a->[0] }
            map { [ stat($_)->mtime, $_ ] }
            File::Find::Rule->file->name(qr/^pubmed\_\d+\.xml$/)
            ->in( $self->data_dir );
		croak "no input file found\n" if !@files;
        $files[0];
    }, 
    lazy => 1
);

sub execute {
    my $self = shift;
    my $log  = $self->dual_logger;

    Modware::DataSource::Chado->connect(
        dsn      => $self->dsn,
        user     => $self->user,
        password => $self->password,
        attr     => $self->attribute
    );
    my $biblio = Bio::Biblio::IO->new(
        -format => 'pubmedxml',
        -file   => $self->input
    );

    my $loaded  = 0;
    my $skipped = 0;
    while ( my $ref = $biblio->next_bibref ) {
        my $pubmed_id = $ref->pmid;
        if ( Modware::Publication::DictyBase->find_by_pubmed_id($pubmed_id) )
        {
            $log->warn("Publication with $pubmed_id exist");
            $skipped++;
            next;
        }
        my $pub = Modware::Publication::DictyBase->new;
        $pub->pubmed_id($pubmed_id);
        $pub->$_( $self->$_ ) for qw/source type/;
        $pub->$_( $ref->$_ )  for qw/title volume status/;
        $pub->issue( $ref->issue )        if $ref->issue;
        $pub->pages( $ref->medline_page ) if $ref->medline_page;
        $pub->abstract( $ref->abstract )  if $ref->abstract;
        $pub->issn($ref->journal->issn) if $ref->journal->issn;

        for my $author ( @{ $ref->authors } ) {
            $pub->add_author(
                {   last_name  => $author->last_name,
                    suffix     => $author->suffix,
                    given_name => $author->initials . ' ' . $author->forename
                }
            );
        }

        try {
            $pub->create;
            $loaded++;
            $log->info("Loaded $pubmed_id");
        }
        catch {
            $log->fatal(
                "Could not load entry with pubmed id $pubmed_id\n$_");
        };
    }
    $log->info("Loaded: $loaded\tSkipped: $skipped");
    my $msg = $log->appender_by_name('message_stack')->string;

	$self->from || $self->from($self->email);
	$self->to || $self->to($self->email);
	$self->subject('Pubmed loader robot');
    $self->email($msg);

}


1;    # Magic true value required at end of module

__END__

=head1 NAME

Load pubmed records in dicty chado database

