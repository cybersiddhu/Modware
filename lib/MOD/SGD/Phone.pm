package MOD::SGD::Phone;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("phone");
__PACKAGE__->add_columns(
  "phone_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "phone_num",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "phone_type",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "phone_location",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
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
__PACKAGE__->set_primary_key("phone_no");
__PACKAGE__->add_unique_constraint(
  "phone_phone_num_type_loc_uk",
  [
    "phone_num",
    "phone_num",
    "phone_num",
    "phone_num",
    "phone_type",
    "phone_type",
    "phone_type",
    "phone_type",
    "phone_location",
    "phone_location",
    "phone_location",
    "phone_location",
  ],
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Gpr+i9m+1fiM1k8xe1tPaw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
