package MOD::SGD::RelatedRef;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("related_ref");
__PACKAGE__->add_columns(
  "reference_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "related_ref_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "pub_type",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "description",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 240,
  },
);
__PACKAGE__->set_primary_key("reference_no", "related_ref_no");


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:S53F3mL+HUIlYOMf3AGFcw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
