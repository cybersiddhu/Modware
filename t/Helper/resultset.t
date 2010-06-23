use strict;
use Test::More qw/no_plan/;
use Data::Dumper;
use Bio::Chado::Schema;

{

    package My::Cv::Resultset;
    use Moose;

    use Bio::Chado::Schema;
    my $schema = Bio::Chado::Schema->connect;

    with 'Modware::Role::Chado::Helper::BCS::ResultSet' => {
        resultset     => $schema->resultset('Cv::Cv')->new( {} ),
        relationships => [qw/cvterms cvtermpaths/]
    };

}

{

    package My::Feature::Resultset;
    use Moose;

    use Bio::Chado::Schema;
    my $schema = Bio::Chado::Schema->connect;

    with 'Modware::Role::Chado::Helper::BCS::ResultSet' => {
        resultset => $schema->resultset('Sequence::Feature')->new( {} ),
        relationships =>
            [qw/feature_pubs analysisfeatures featureprops type dbxref/],
        columns => [qw/name uniquename residues seqlen dbxref_id/]
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
    use Bio::Chado::Schema;

    my $schema = Bio::Chado::Schema->connect;
    has 'pub' => (
        is     => 'ro',
        traits => [
            'Modware::Role::Chado::Helper::BCS::ResultSet' => {
                resultset     => $schema->resultset('Pub::Pub')->new( {} ),
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

my $schema = Bio::Chado::Schema->connect;
$pub->meta->add_attribute(
    'superpub' => (
        is     => 'ro',
        traits => [
            'Modware::Role::Chado::Helper::BCS::ResultSet' => {
                resultset     => $schema->resultset('Pub::Pub')->new( {} ),
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

