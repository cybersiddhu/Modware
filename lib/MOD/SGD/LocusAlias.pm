package MOD::SGD::LocusAlias;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("locus_alias");
__PACKAGE__->add_columns(
  "locus_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "alias_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:OtrH0QqRNZQxONKrLDYNqA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
