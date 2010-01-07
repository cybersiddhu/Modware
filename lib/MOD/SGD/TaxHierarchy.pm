package MOD::SGD::TaxHierarchy;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("tax_hierarchy");
__PACKAGE__->add_columns(
  "parent_id",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "child_id",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "generation",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 2 },
);
__PACKAGE__->set_primary_key("parent_id", "child_id");


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:bhvU7JJ0FGwVkYraAWEv8w


# You can replace this text with custom content, and it will be preserved on regeneration
1;
