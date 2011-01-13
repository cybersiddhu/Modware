package Modware::Update::Command::pubindicty;
use strict;

# Other modules:
use namespace::autoclean;
use Moose;
use Bio::DB::EUtilities;
use Modware::DataSource::Chado;
use Modware::Publication::DictyBase;
use Try::Tiny;
use Carp;
use XML::LibXML;
extends qw/Modware::Update::Command/;
with 'Modware::Role::Command::WithEmail';
with 'Modware::Role::Command::WithLogger';

# Module implementation
#

has '+input' => ( traits => [qw/NoGetopt/] );
has '+data_dir' => ( traits => [qw/NoGetopt/] );

has 'threshold' => (
    is      => 'ro',
    isa     => 'Int',
    default => 100,
    traits  => [qw/NoGetopt/]
);

has 'status' => (
    is            => 'rw',
    isa           => 'Str',
    default       => 'aheadofprint',
    documentation => 'Status of published article that will be searched for update,  default is *aheadofprint*'
);

has 'exist_count' => (
    is      => 'rw',
    isa     => 'Num',
    default => 0,
    traits  => [qw/Counter NoGetopt/],
    handles => {
        set_exist_count => 'set',
        inc_exist       => 'inc'
    }
);

sub execute {
    my $self = shift;
    my $log  = $self->dual_logger;
    $self->subject('Pubmed loader robot');

    Modware::DataSource::Chado->connect(
        dsn      => $self->dsn,
        user     => $self->user,
        password => $self->password,
        attr     => $self->attribute
    );

    my $ids;
    my $itr
        = Modware::Publication::DictyBase->search( status => $self->status );
    $self->set_total_count( $itr->count );
    $log->info( "Going to process ",
        $self->total_count, " ", $self->status, " pubmed records" );

PUB:
    while ( my $pub = $itr->next ) {
        if ( $pub->has_full_text ) {
        	$self->inc_exist;
            next PUB;
        }
        push @$ids, $pub->pubmed_id;
        if ( @$ids >= $self->threshold ) {
            $self->process_id(
                ids => $ids,
                log => $log,
            );
            undef $ids;
        }
    }

    if (@$ids) {    ## -- leftover
        $self->process_id(
            ids => $ids,
            log => $log,
        );
    }

    $log->info( 'exist:',  $self->exist_count,
        ' updated:', $self->update_count, ' error:',   $self->error_count );

}

sub process_id {
    my ( $self, %arg ) = @_;
    my $ids    = $arg{ids};
    my $log    = $arg{log};

    my $eutils = Bio::DB::EUtilities->new(
        -eutil  => 'elink',
        -dbfrom => 'pubmed',
        -cmd    => 'prlinks',
        -id     => $ids
    );

    my $res = $eutils->get_Response;
    if ( $res->is_error ) {
        $log->error( $res->code, "\t", $res->message );
        return;
    }

    my $xml = XML::LibXML->new->parse_file( $res->content );
    if ( !$xml->exists( $self->xpath_query ) ) {
        $log->warn('No full text links found');
        return;
    }

    for my $node ( $xml->findnodes( $self->xpath_query ) ) {
        my $pubmed_id = $node->find('Id');
        my $url       = $node->find('ObjUrl/Url');

        my $dicty_pub
            = Modware::Publication::DictyBase->find_by_pubmed_id($pubmed_id);

        if ($dicty_pub) {
            $dicty_pub->full_text_url($url);
            try {
                $dicty_pub->update;
                $log->info("updated full text url for pubmed_id: $pubmed_id");
                $self->inc_update;
            }
            catch {
                $log->error(
                    "Error in updating full text url with pubmed id: $pubmed_id"
                );
                $log->error($_);
                $self->inc_error;
            };
        }
        else {
            $log->warn("Cannot find publication with pubmed id: $pubmed_id");
        }
    }
    return 1;
}

1;    # Magic true value required at end of module

__END__

=head1 NAME

Update full text url of pubmed records in dicty chado database

