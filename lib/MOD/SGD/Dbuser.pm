package MOD::SGD::Dbuser;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("dbuser");
__PACKAGE__->add_columns(
  "userid",
  {
    data_type => "VARCHAR2",
    default_value => "SUBSTR(USER,1,20) ",
    is_nullable => 0,
    size => 20,
  },
  "first_name",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "last_name",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "status",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "email",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 100,
  },
  "date_created",
  {
    data_type => "DATE",
    default_value => "SYSDATE ",
    is_nullable => 0,
    size => 19,
  },
);
__PACKAGE__->set_primary_key("userid");


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:nIgo9D4gIQhpi6kMYUVuAQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
