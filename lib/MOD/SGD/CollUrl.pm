package MOD::SGD::CollUrl;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("coll_url");
__PACKAGE__->add_columns(
  "colleague_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "url_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
);
__PACKAGE__->set_primary_key("colleague_no", "url_no");


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:YBeTA6575niEG3xHTO/5PA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
