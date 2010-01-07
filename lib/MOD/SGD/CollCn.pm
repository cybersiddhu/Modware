package MOD::SGD::CollCn;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("coll_cn");
__PACKAGE__->add_columns(
  "colleague_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "curator_note_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
);
__PACKAGE__->set_primary_key("colleague_no", "curator_note_no");


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:knVGWsB9aVGuSLJO5Gf1Og


# You can replace this text with custom content, and it will be preserved on regeneration
1;
