package MOD::SGD::ReferenceCitationMatcher;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("reference_citation_matcher");
__PACKAGE__->add_columns(
  "reference",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 365,
  },
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9NSfUz5nUPAqCM//UbfAIg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
