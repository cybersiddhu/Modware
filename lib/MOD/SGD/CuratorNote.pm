package MOD::SGD::CuratorNote;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("curator_note");
__PACKAGE__->add_columns(
  "curator_note_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "note",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 960,
  },
  "is_public",
  {
    data_type => "VARCHAR2",
    default_value => "'N' ",
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
);
__PACKAGE__->set_primary_key("curator_note_no");
__PACKAGE__->add_unique_constraint("curator_note_uk", ["note", "note", "note", "note"]);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:w9AB+iC4Ievu02Yw0hAEBQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
