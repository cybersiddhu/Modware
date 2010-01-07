package MOD::SGD::Keyword;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("keyword");
__PACKAGE__->add_columns(
  "keyword_no",
  { data_type => "NUMBER", default_value => undef, is_nullable => 0, size => 10 },
  "keyword",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 100,
  },
  "source",
  {
    data_type => "VARCHAR2",
    default_value => undef,
    is_nullable => 0,
    size => 40,
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
__PACKAGE__->set_primary_key("keyword_no");
__PACKAGE__->add_unique_constraint("keyword_uk", ["keyword", "keyword", "keyword", "keyword"]);


# Created by DBIx::Class::Schema::Loader v0.04006 @ 2010-01-07 10:55:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:tixOmjSr3I4qFzoz0IFtpg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
