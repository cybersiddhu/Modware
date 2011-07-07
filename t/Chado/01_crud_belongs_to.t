use Test::More qw/no_plan/;
use Test::Exception;
use aliased 'Modware::DataSource::Chado';
use Modware::Build;
use Data::Dump qw/pp/;

my $build = Modware::Build->current;
Chado->connect( $build->connect_hash );

use_ok('TestAssay');
subtest 'Test::Modware::Chado::AssayProject' => sub {
    my $project;
    lives_ok {
        $project = Test::Modware::Chado::Project->create(
            name        => 'test_project',
            description => 'A project for testing'
        );
    }
    'creates a new project instance';

    my $assay;
    lives_ok {
        $assay = Test::Modware::Chado::Assay->create(
            name           => 'test_assay',
            description    => 'A assay for testing',
            arraydesign_id => 25,
            operator_id    => 29,
            dbxref_id      => 10
        );
    }
    'creates a new assay instance';

    my $ap = new_ok('Test::Modware::Chado::AssayProject');
    dies_ok { $ap->save } 'cannot be saved without assay and project';

    $ap->assay($assay);
    $ap->project($project);

    my $ap_fromdb;
    lives_ok {
        $ap_fromdb = $ap->save;
    }
    'saved in database after associated with assay and project';

    is( $ap_fromdb->assay_id,   $assay->assay_id,     'matches assay id' );
    is( $ap_fromdb->project_id, $project->project_id, 'matches project id' );
    isa_ok( $ap_fromdb->assay,   'Test::Modware::Chado::Assay' );
    isa_ok( $ap_fromdb->project, 'Test::Modware::Chado::Project' );
    is( $ap_fromdb->assay->name,   $assay->name,   'matches assay name' );
    is( $ap_fromdb->project->name, $project->name, 'matches project name' );

    my $assay_fromdb = $ap_fromdb->assay;
    $assay_fromdb->name('test_assay update');
    $ap_fromdb->assay($assay_fromdb);
    lives_ok {
        $ap_fromdb->update;
    }
    'updated';
    is( $ap_fromdb->assay->name, $assay_fromdb->name,
        'matches assay name after update' );

	lives_ok {
		$ap_fromdb->delete
	}
	'deleted';
};


