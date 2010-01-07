package MOD::SGD::PdbAlignment;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("pdb_alignment");
__PACKAGE__->add_columns(
  "pdb_alignment_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "query_seq_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "target_seq_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "method",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "matrix",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "query_align_start_coord",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "query_align_stop_coord",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "target_align_start_coord",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "target_align_stop_coord",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "pct_aligned",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 5 },
  "pct_identical",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 5 },
  "pct_similar",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 5 },
  "score",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 8 },
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
__PACKAGE__->set_primary_key("pdb_alignment_no");
__PACKAGE__->add_unique_constraint(
  "pdb_alignment_uk",
  [
    "query_seq_no",
    "query_seq_no",
    "query_seq_no",
    "query_seq_no",
    "target_seq_no",
    "target_seq_no",
    "target_seq_no",
    "target_seq_no",
  ],
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZEqAVa9uXBBuXTb9tb6cmg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
