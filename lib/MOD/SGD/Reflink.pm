package MOD::SGD::Reflink;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("reflink");
__PACKAGE__->add_columns(
  "reflink_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "reference_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "tab_name",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 30,
  },
  "primary_key",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 500,
  },
  "primary_key_col",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 100,
  },
  "col_name",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 30,
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
__PACKAGE__->set_primary_key("reflink_no");
__PACKAGE__->add_unique_constraint(
  "reflink_uk",
  [
    "tab_name",
    "tab_name",
    "tab_name",
    "tab_name",
    "primary_key",
    "primary_key",
    "primary_key",
    "primary_key",
    "primary_key_col",
    "primary_key_col",
    "primary_key_col",
    "primary_key_col",
    "reference_no",
    "reference_no",
    "reference_no",
    "reference_no",
    "col_name",
    "col_name",
    "col_name",
    "col_name",
  ],
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:D1jH4/qoyO6KAIx9BD8KNA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
