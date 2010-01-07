package MOD::SGD::GoSynonym;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("go_synonym");
__PACKAGE__->add_columns(
  "go_synonym_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "go_synonym",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 240,
  },
  "date_created",
  {
    data_type => "DATE",
    default_value => "SYSDATE ",
    is_nullable => 0,
    size => 19,
  },
  "created_by",
  {
    data_type => "VARCHAR2",
    default_value => "SUBSTR(USER,1,12) ",
    is_nullable => 0,
    size => 12,
  },
);
__PACKAGE__->set_primary_key("go_synonym_no");
__PACKAGE__->add_unique_constraint(
  "go_synonym_uk",
  ["go_synonym", "go_synonym", "go_synonym", "go_synonym"],
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8Yl1Xyoge30bGhwwDsPrPg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
