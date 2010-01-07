package MOD::SGD::Dictybaseid;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("dictybaseid");
__PACKAGE__->add_columns(
  "dictybaseid_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "dictybaseid",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 10,
  },
  "dictybaseid_type",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "tab_name",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 30,
  },
  "primary_key",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 40,
  },
  "curator_note_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 1, size => 10 },
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
  "replaced_by",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 10,
  },
);
__PACKAGE__->set_primary_key("dictybaseid_no");
__PACKAGE__->add_unique_constraint(
  "dictybaseid_u",
  ["dictybaseid", "dictybaseid", "dictybaseid", "dictybaseid"],
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:fHjMb65s64ewzmDFdqqdew


# You can replace this text with custom content, and it will be preserved on regeneration
1;
