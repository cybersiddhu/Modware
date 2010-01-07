package MOD::SGD::FeatGeneInfo;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("feat_gene_info");
__PACKAGE__->add_columns(
  "feature_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "reference_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "literature_topic",
  {
    data_type => "VARCHAR2",
    default_value => "'Not yet curated' ",
    is_nullable => 0,
    size => 40,
  },
  "last_curated",
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
__PACKAGE__->set_primary_key("feature_no", "reference_no", "literature_topic");


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wmGBxphxxQ7KoAMvlwgmHg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
