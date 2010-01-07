package MOD::SGD::Go;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("go");
__PACKAGE__->add_columns(
  "goid",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "go_term",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 240,
  },
  "go_aspect",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "go_definition",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 2000,
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
__PACKAGE__->set_primary_key("goid");
__PACKAGE__->add_unique_constraint(
  "go_term_aspect_uk",
  [
    "go_term",
    "go_term",
    "go_term",
    "go_term",
    "go_aspect",
    "go_aspect",
    "go_aspect",
    "go_aspect",
  ],
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:mSy9zBhM3MNTzds7Lyftzg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
