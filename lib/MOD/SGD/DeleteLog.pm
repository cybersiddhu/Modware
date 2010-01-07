package MOD::SGD::DeleteLog;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("delete_log");
__PACKAGE__->add_columns(
  "dlog_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "tab_name",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 30,
  },
  "deleted_row",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 4000,
  },
  "description",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 240,
  },
  "date_modified",
  {
    data_type => "DATE",
    default_value => "SYSDATE ",
    is_nullable => 0,
    size => 19,
  },
  "modified_by",
  {
    data_type => "VARCHAR2",
    default_value => "SUBSTR(USER,1,12) ",
    is_nullable => 0,
    size => 12,
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
__PACKAGE__->set_primary_key("dlog_no");


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Vd1bS+8+XS2zQJaY+lJBTw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
