package MOD::SGD::RefUnlink;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("ref_unlink");
__PACKAGE__->add_columns(
  "ref_unlink_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "pubmed",
  { data_type => "NUMBER", default_value => undef, is_nullable => 1, size => 10 },
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
    size => 40,
  },
  "reference_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
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
__PACKAGE__->set_primary_key("ref_unlink_no");
__PACKAGE__->add_unique_constraint(
  "ru_uk",
  [
    "reference_no",
    "reference_no",
    "reference_no",
    "reference_no",
    "tab_name",
    "tab_name",
    "tab_name",
    "tab_name",
    "primary_key",
    "primary_key",
    "primary_key",
    "primary_key",
  ],
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:goxh4FYxkyT/onenVa63Ig


# You can replace this text with custom content, and it will be preserved on regeneration
1;
