package MOD::SGD::Goannotationdate;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("goannotationdate");
__PACKAGE__->add_columns(
  "locus_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "date_locus_curated",
  { data_type => "DATE", default_value => undef, is_nullable => 0, size => 19 },
  "goid",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3ytYPCIdFy3oC3Vm1tqGqQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
