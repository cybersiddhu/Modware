package Modware::Export::Command::dictygaf;
use strict;

# Other modules:
use namespace::autoclean;
use Moose;
extends qw/Modware::Export::GAF/;
with 'Modware::Role::Command::WithEmail';

# Module implementation
#

has '+input'          => ( traits => [qw/NoGetopt/] );
has '+data_dir'       => ( traits => [qw/NoGetopt/] );
has '+output_handler' => ( traits => [qw/NoGetopt/] );

has '+gafcv' => (
    default => 'gene_ontology_association',
    documentation =>
        'The cv namespace for storing gaf metadata such as source, with, qualifier and
        date column in chado database,  default is *gene_ontology_association*'
);

has '+date_term' => (
    default       => 'date',
    documentation => 'Cv term for storing date column,  default is *date*'
);

has '+with_term' => (
    default       => 'with',
    documentation => 'Cv term for storing with column,  default is *with*'
);

has '+source_term' => (
    default       => 'source',
    documentation => 'Cv term for storing source column,  default is *source*'
);

has '+qual_term' => (
    default => 'qualifier',
    documentation =>
        'Cv term for storing qualifier column,  default is *qualifier*'
);

has '+taxon_id' => (
    default       => 44689,
    documentation => 'The NCBI taxon id,  default is *44689*'
);

has '+source_database' => (
    default => 'dictyBase',
    documentation =>
        'The source database from which identifier is drawn,  represents column 1 of
        GAF2.0,  default is dictyBase'
);

has '+common_name' => (
    default => 'dicty'

);

sub get_description {
    my ($self, $feat) = @_;
    my $rs = $feat->featureprops(
        { 'type.name' => 'name description' },
        { join        => 'type' }
    );
    return $rs->first->value if $rs->count;
}

sub get_provenance {
    my ( $self, $row ) = @_;
    my $pub = $row->pub->uniquename;
    if ( $pub =~ /^PUB/ ) {
        $pub =~ s/^PUB//;
        return 'dicty_REF:' . $pub;
    }
    return $self->pubmed_namespace . ':' . $pub;
}

1;    # Magic true value required at end of module

__END__

=head1 NAME

Dump GAF2.0 file from chado database

