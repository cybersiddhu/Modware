use strict;
use Test::Most qw/no_plan die/;
use aliased 'ModwareX::DataSource::Chado';
use aliased 'ModwareX::ConfigData';

{

    package My::Helper::Cv;
    use Moose;
    use aliased 'ModwareX::DataSource::Chado';

    has 'cv' => ( is => 'rw', isa => 'Str', default => 'pub_type' );
    has 'db' => ( is => 'rw', isa => 'Str', default => 'modwarex' );
    has 'chado' => (
        is      => 'rw',
        isa     => 'Bio::Chado::Schema',
        default => sub {
            Chado->handler;
        }
    );

    with 'ModwareX::Role::Chado::Reader::BCS::Helper::Cvterm';

    __PACKAGE__->meta->make_immutable;
    no Moose;
}

Chado->connect(
    dsn      => ConfigData->config('dsn'),
    user     => ConfigData->config('user'),
    password => ConfigData->config('password')
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
    = $helper->cvterm_ids_by_namespace('ModwareX-relation-relationship');
like( scalar @$rel_ids, qr/\d{2}/, 'it return relationship cvterm ids' );
