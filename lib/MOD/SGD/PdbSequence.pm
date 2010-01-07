package MOD::SGD::PdbSequence;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("pdb_sequence");
__PACKAGE__->add_columns(
  "pdb_sequence_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "sequence_name",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 50,
  },
  "source",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "organism",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "sequence_length",
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
  "note",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 1,
    size => 960,
  },
);
__PACKAGE__->set_primary_key("pdb_sequence_no");
__PACKAGE__->add_unique_constraint(
  "pdb_sequence_name_uk",
  [
    "sequence_name",
    "sequence_name",
    "sequence_name",
    "sequence_name",
  ],
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:04wGmiHLUA2FiiSHk3VUiA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
