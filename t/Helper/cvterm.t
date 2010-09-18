use strict;
use Test::More qw/no_plan/;
use aliased 'Modware::DataSource::Chado';
use Modware::Build;

{

    package My::Helper::Cv;
    use Moose;
    use aliased 'Modware::DataSource::Chado';
    use namespace::autoclean;

    has 'cv' => ( is => 'rw', isa => 'Str', default => 'pub_type' );
    has 'db' => ( is => 'rw', isa => 'Str', default => 'modwarex' );
    has 'chado' => (
        is      => 'rw',
        isa     => 'Bio::Chado::Schema',
        default => sub {
            Chado->handler;
        }
    );

    with 'Modware::Role::Chado::Helper::BCS::Cvterm';

    __PACKAGE__->meta->make_immutable;
}

my $build = Modware::Build->current;
Chado->connect(
    dsn      => $build->config_data('dsn'),
    user     => $build->config_data('user'),
    password => $build->config_data('password')
);

my $helper = My::Helper::Cv->new;
dies_ok { $helper->cvterm_id_by_name } 'it throws without passing a cvterm';
like( $helper->cvterm_id_by_name('gene'),
    qr/\d+/, 'it return an id for an existing cvterm from so' );
like( $helper->cvterm_id_by_name('is_a'),
    qr/\d+/, 'it return an id for an existing cvterm from rel ontology' );
like( $helper->cvterm_id_by_name('archive'),
    qr/\d+/, 'it return an id for an existing cvterm from pub ontology' );
like( $helper->cvterm_id_by_name('curtain'), qr/\d+/,
    'it return an id for an non existing cvterm after creating it on the fly'
);

dies_ok { $helper->cvterm_ids_by_namespace }
'it throws without any namespace given';
dies_ok { $helper->cvterm_ids_by_namespace('blind') }
'it throws with a non-existing namespace';

my $rel_ids
    = $helper->cvterm_ids_by_namespace('Modware-relation-relationship');
like( scalar @$rel_ids, qr/\d{2}/, 'it return relationship cvterm ids' );
