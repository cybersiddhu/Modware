package MOD::SGD::GoPath;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("go_path");
__PACKAGE__->add_columns(
  "go_path_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "ancestor_goid",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "child_goid",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "generation",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 2 },
  "ancestor_path",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 240,
  },
  "relationship_type",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 40,
  },
);
__PACKAGE__->set_primary_key("go_path_no");
__PACKAGE__->add_unique_constraint(
  "go_path_uk",
  [
    "ancestor_path",
    "ancestor_path",
    "ancestor_path",
    "ancestor_path",
    "child_goid",
    "child_goid",
    "child_goid",
    "child_goid",
  ],
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IYRDi8f7xR3v2tdBDpK3mQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
