package MOD::SGD::Code;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("code");
__PACKAGE__->add_columns(
  "code_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "tab_name",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 30,
  },
  "col_name",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 30,
  },
  "code_value",
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
__PACKAGE__->set_primary_key("code_no");
__PACKAGE__->add_unique_constraint(
  "code_tab_col_code_uk",
  [
    "tab_name",
    "tab_name",
    "tab_name",
    "tab_name",
    "col_name",
    "col_name",
    "col_name",
    "col_name",
    "code_value",
    "code_value",
    "code_value",
    "code_value",
  ],
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FbRAuARVYyY2OGouNcW+KA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
