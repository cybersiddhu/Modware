package MOD::SGD::Colleague;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("colleague");
__PACKAGE__->add_columns(
  "colleague_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "last_name",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "first_name",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "suffix",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 40,
  },
  "other_name",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 40,
  },
  "profession",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 100,
  },
  "job_title",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 100,
  },
  "institution",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 100,
  },
  "address1",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 80,
  },
  "address2",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 80,
  },
  "address3",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 80,
  },
  "address4",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 80,
  },
  "address5",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 80,
  },
  "city",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 100,
  },
  "state",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 2,
  },
  "region",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 40,
  },
  "country",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 40,
  },
  "postal_code",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 40,
  },
  "source",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "date_modified",
  {
    data_type => "DATE",
    default_value => "SYSDATE ",
    is_nullable => 0,
    size => 19,
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
  "is_subscribed",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 1,
  },
);
__PACKAGE__->set_primary_key("colleague_no");


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xbDnfncEPYJWMyCy/g+4HQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
