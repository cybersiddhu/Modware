package MOD::SGD::Alias;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("alias");
__PACKAGE__->add_columns(
  "alias_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 11 },
  "alias_name",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 255,
  },
  "alias_type",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 1024,
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
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KO99dxWG6B+cmh5Ch1Pq+g


# You can replace this text with custom content, and it will be preserved on regeneration
1;
