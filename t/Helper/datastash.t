use strict;
use Test::More qw/no_plan/;
use Data::Dumper::Concise;

{

    package MyDefault;
    use Moose;
    with 'Modware::Role::Chado::Helper::BCS::WithDataStash';

}

{

    package MyDefault::Create;
    use Moose;

    with 'Modware::Role::Chado::Helper::BCS::WithDataStash' =>
        { create_stash_for => [qw/dbxref featureprops/] };

}

{

    package MyDefault::All;
    use Moose;

    with 'Modware::Role::Chado::Helper::BCS::WithDataStash' => {
        create_stash_for => [qw/dbxref featureprops/],
        update_stash_for => {
            has_many     => [qw/featuresource analysis/],
            many_to_many => [qw/pipes/]
        }
    };

}

my $stash = MyDefault->new;
can_ok(
    $stash, qw/mapper update_hashref insert_hashref add_to_mapper get_map
        mapped_columns empty_mapper/
);

my $map_hash = {
    name        => 'hello',
    definition  => 'nothing to say',
    description => 'blueprint',
    dbxref_id   => 50
};

$stash->add_to_mapper( $_, $map_hash->{$_} ) for keys %$map_hash;
is_deeply(
    $stash->update_hashref, $map_hash, 'It returns the expected hash data
structure'
);
is_deeply(
    $stash->insert_hashref, $stash->update_hashref, 'Insert and update hashref
method returns the identical hash structure'
);

my $cstash = MyDefault::Create->new;
can_ok(
    $cstash,
    qw/create_stash insert_dbxref insert_featureprops add_to_insert_dbxref
        add_to_insert_featureprops/
);

my $chash1 = {
    db_id     => 20,
    name      => 'utopia',
    accession => 48943
};

my $chash2 = {
    db_id     => 120,
    name      => 'utopian',
    accession => 489434439
};

my $chash3 = {
    feature_id => 120,
    value      => 'yadayada'
};

my $chash4 = {
    feature_id => 483,
    value      => 'sideler'
};

$cstash->add_to_mapper( $_, $map_hash->{$_} ) for keys %$map_hash;
$cstash->add_to_insert_dbxref($chash1);
$cstash->add_to_insert_dbxref($chash2);
$cstash->add_to_insert_featureprops($chash3);
$cstash->add_to_insert_featureprops($chash4);

my $cmap_hash = $map_hash;
$cmap_hash->{dbxref}       = [ $chash1, $chash2 ];
$cmap_hash->{featureprops} = [ $chash3, $chash4 ];

is_deeply(
    $cstash->insert_hashref, $cmap_hash, 'It returns the expected insert data
structure'
);

my $ustash = MyDefault::All->new;
can_ok(
    $ustash, qw/has_many_update_stash many_to_many_update_stash
        add_to_update_featuresource add_to_update_analysis add_to_update_pipes all_update_pipes
        all_update_analysis all_update_featuresource/
);

$ustash->add_to_mapper( $_, $map_hash->{$_} ) for keys %$map_hash;
$ustash->add_to_update_featuresource($chash1);
$ustash->add_to_update_featuresource($chash1);
$ustash->add_to_update_pipes($chash2);
$ustash->add_to_update_pipes($chash2);

is_deeply( $ustash->update_hashref, $map_hash,
    'It returns the update hashref' );
is_deeply( $_, $chash1, 'It returns the hashref for featuresource update' )
    for $ustash->all_update_featuresource;
is_deeply( $_, $chash2, 'It returns the hashref for pipes update' )
    for $ustash->all_update_pipes;

