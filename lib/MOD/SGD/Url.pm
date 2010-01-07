package MOD::SGD::Url;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("url");
__PACKAGE__->add_columns(
  "url_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "url",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 480,
  },
  "url_type",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "www_name",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 100,
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
__PACKAGE__->set_primary_key("url_no");
__PACKAGE__->add_unique_constraint(
  "url_type_uk",
  [
    "url",
    "url",
    "url",
    "url",
    "url_type",
    "url_type",
    "url_type",
    "url_type",
  ],
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:QKpzVj2SlDQmV8gM8u68Hw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
