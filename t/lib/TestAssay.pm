package Test::Modware::Chado::Assay;
use Modware::Chado;

bcs_resultset 'Mage::Assay';
chado_skip_all_attributes [qw/arrayidentifier arraybatchidentifier/];

1;

package Test::Modware::Chado::Project;
use Modware::Chado;
bcs_resultset 'General::Project';
1;

package Test::Modware::Chado::AssayProject;
use Modware::Chado;

bcs_resultset 'Mage::AssayProject';
chado_belongs_to 'assay' => (class => 'Test::Modware::Chado::Assay');
chado_belongs_to 'project' => (class => 'Test::Modware::Chado::Project');

1;



1;    # Magic true value required at end of module

