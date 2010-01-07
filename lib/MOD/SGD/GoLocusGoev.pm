package MOD::SGD::GoLocusGoev;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("go_locus_goev");
__PACKAGE__->add_columns(
  "goid",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "locus_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "go_evidence_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "is_not",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 1,
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
  "with_from",
  { data_type => "NUMBER", default_value => undef, is_nullable => 1, size => 38 },
  "is_contributes_to",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 50,
  },
  "is_colocalizes_with",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 50,
  },
);
__PACKAGE__->set_primary_key("goid", "locus_no", "go_evidence_no", "is_not");


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:rO/UrVeJ2JM1gWN77yBqCQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
