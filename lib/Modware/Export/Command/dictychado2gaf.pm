package Modware::Export::Command::dictychado2gaf;
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

has '+gafcv' => ( default => 'gene_ontology_association');

has '+date_term' => (
	default => 'date'
);

has '+with_term' => (
	default => 'with'
);

has '+source_term' => (
	default => 'source'
);

has '+qual_term' => (
	default => 'qualifier'
);

has '+taxon_id' => (
	default => 44689
);

has '+source_database' => (
	default => 'dictyBase'
);

has '+common_name' => (
	default => 'dicty'
);

sub get_provenance {
    my ( $self, $row ) = @_;
    my $pub = $row->pub->uniquename;
    if ($pub =~ /^PUB/) {
    	$pub =~ s/^PUB//;
    	return 'dicty_REF:'.$pub;
    }
    return $self->pubmed_namespace.':'.$pub;
}

1;    # Magic true value required at end of module

__END__

=head1 NAME

Dump GAF2.0 file from chado database

