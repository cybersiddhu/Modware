package MOD::SGD::RefUrl;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("ref_url");
__PACKAGE__->add_columns(
  "reference_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "url_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
);
__PACKAGE__->set_primary_key("reference_no", "url_no");


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:R+5I4wfAaM8foxDrmqIQug


# You can replace this text with custom content, and it will be preserved on regeneration
1;
