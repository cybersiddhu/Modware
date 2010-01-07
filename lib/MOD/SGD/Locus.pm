package MOD::SGD::Locus;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("locus");
__PACKAGE__->add_columns(
  "locus_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 11 },
  "locus_name",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 255,
  },
  "chromosome",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 0,
  },
  "genetic_position",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 0,
  },
  "enzyme",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 0,
  },
  "description",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 0,
  },
  "paragraph_no",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 0,
  },
  "date_modified",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 0,
  },
  "date_created",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 0,
  },
  "created_by",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 0,
  },
  "name_description",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 0,
  },
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Jph0meRsX/2CKg5QJbN3oA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
