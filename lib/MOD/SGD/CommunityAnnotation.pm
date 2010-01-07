package MOD::SGD::CommunityAnnotation;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("community_annotation");
__PACKAGE__->add_columns(
  "community_annotation_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "annotation_set_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "dictybaseid",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "topic",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "sub_topic",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
  },
  "description",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 480,
  },
);
__PACKAGE__->set_primary_key("community_annotation_no");
__PACKAGE__->add_unique_constraint(
  "community_annotation_uk",
  [
    "dictybaseid",
    "dictybaseid",
    "dictybaseid",
    "dictybaseid",
    "topic",
    "topic",
    "topic",
    "topic",
    "sub_topic",
    "sub_topic",
    "sub_topic",
    "sub_topic",
    "description",
    "description",
    "description",
    "description",
    "annotation_set_no",
    "annotation_set_no",
    "annotation_set_no",
    "annotation_set_no",
  ],
);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:aiL79qM26NPJy91xgtg9HQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
