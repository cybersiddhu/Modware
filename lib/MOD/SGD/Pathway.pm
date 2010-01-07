package MOD::SGD::Pathway;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("pathway");
__PACKAGE__->add_columns(
  "pathway_id",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 11 },
  "pathway_name",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 50,
  },
  "common_name",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 200,
  },
);
__PACKAGE__->set_primary_key("pathway_id");


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sWDw4hZXwBNe73Ly8VU6Mw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
