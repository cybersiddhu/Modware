use strict;
use Test::More qw/no_plan/;

{

    package MyDefault;
    use Moose;
    with 'Modware::Role::Chado::Helper::WithDataStash'; 

}

{

    package MyDefault::Create;
    use Moose;

    with 'Modware::Role::Chado::Helper::WithDataStash' => {
        create_stash_for => [qw/dbxref featureprops/]
    };

}

{

    package MyDefault::All;
    use Moose;

    with 'Modware::Role::Chado::Helper::WithDataStash' => {
        create_stash_for => [qw/dbxref featureprops/], 
        update_stash_for => {
        	has_many => [qw/featuresource analysis/], 
        	many_to_many => [qw/pipes/]
        }
    };

}


my $rs = My::Cv::Resultset->new;
$rs->name('hello');
$rs->definition('nothing to say');
$rs->add_to_cvterms(
    { name => 'gene', description => 'blueprint', dbxref_id => 50 } );

my $hash = {
    name       => 'hello',
    definition => 'nothing to say',
    cvterms    => [
        {   name        => 'gene',
            description => 'blueprint',
            dbxref_id   => 50
        }
    ]
};

can_ok( 'My::Cv::Resultset',
    qw/name definition add_to_cvterms add_to_cvtermpaths has_cvterms/ );
is_deeply( $rs->to_insert_hashref, $hash, 'it returns the expected hashref' );

my $feat = My::Feature::Resultset->new;
can_ok(
    'My::Feature::Resultset', qw/name uniquename residues seqlen dbxref_id
        add_to_featureprops has_feature_pubs type/
);

$hash = {
    name         => 'feature',
    uniquename   => 'superfeature',
    seqlen       => 20,
    dbxref_id    => 5,
    featureprops => [
        {   type_id => 199,
            value   => 'no value',
            rank    => 11
        }
    ]
};

$feat->name('feature');
$feat->uniquename('superfeature');
$feat->seqlen(20);
$feat->dbxref_id(5);
$feat->add_to_featureprops(
    {   type_id => 199,
        value   => 'no value',
        rank    => 11
    }
);

is_deeply( $feat->to_insert_hashref, $hash,
    'it returns the expected feature hashref' );

$feat->type( { name => 'protein', description => 'nobody knows' } );
$hash->{type} = { name => 'protein', description => 'nobody knows' };
is_deeply( $feat->to_insert_hashref, $hash,
    'it returns the expected feature hashref with belongs_to relationship' );

{

    package My::Pub::Resultset;
    use Moose;
    has 'pub' => (
        is     => 'ro',
        traits => [
            'Modware::Role::Chado::Helper::BCS::ResultSet' => {
                resultset     => 'Pub::Pub',
                relationships => [qw/pubprops pubauthors/]
            }
        ]
    );
}

my $pub  = My::Pub::Resultset->new;
my $attr = $pub->meta->get_attribute('pub');
can_ok(
    $attr,
    qw(title volume volumetitle series_name type_id uniquename publisher
        pubprops pubauthors add_to_pubprops add_to_pubauthors)
);

$pub->meta->add_attribute(
    'superpub' => (
        is     => 'ro',
        traits => [
            'Modware::Role::Chado::Helper::BCS::ResultSet' => {
                resultset     => 'Pub::Pub',
                relationships => [qw/pubprops pubauthors/]
            }
        ]
    )
);

my $attr2 = $pub->meta->get_attribute('superpub');
can_ok(
    $attr2,
    qw(title volume volumetitle series_name type_id uniquename publisher
        pubprops pubauthors add_to_pubprops add_to_pubauthors)
);


