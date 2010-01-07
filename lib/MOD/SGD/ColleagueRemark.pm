package MOD::SGD::ColleagueRemark;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("colleague_remark");
__PACKAGE__->add_columns(
  "remark_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "remark",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 1500,
  },
  "remark_type",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "remark_date",
  {
    data_type => "DATE",
    default_value => "SYSDATE ",
    is_nullable => 0,
    size => 19,
  },
  "colleague_no",
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
__PACKAGE__->set_primary_key("remark_no");


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:dXVr171oPwzorWC9SnsmKA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
