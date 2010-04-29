package dicty::DB::DBI;

# Created by SQL::Translator::Producer::Turnkey
# Template used: classdbi

use strict;
no warnings 'redefine';
use base 'dicty::DB::Oracle::Chado';

=head2 Sequence_name_from_table

 Title    : Sequence_name_from_table
 Usage    : Used internally (overriden to change format of seqeunces)
 Function : Given a table name and another argumetn (user specified),
          : create sequence name.  This is based on the Chado conventions
          : Other implementations will have to override.
 Returns  : string (Sequence_name)
 Args     : 

=cut

sub Sequence_name_from_table{
   my($class, $table, $other) = @_;

   my $seq_name = uc("${table}_SEQ");
   return $seq_name;
}

=head2 owner

 Title    : owner
 Usage    : my $owner = $self->owner();
 Function : returns owner for the schema of the table being set up
          : Need this because sometimes we query the CGM_DDB schema
          : Even though we are logged in as CGM_CHADO
 Returns  : owner string
 Args     : none

=cut

sub owner {
   $ENV{'DBUSER'};
}

# -------------------------------------------------------------------
package dicty::DB::Stock_center;
use base 'dicty::DB::DBI';
use Class::DBI::Pager;

dicty::DB::Stock_center->set_up_table('Stock_center');


__PACKAGE__->set_sql(set_sysdate => qq{
   UPDATE __TABLE__
      SET  date_modified = SYSDATE, date_created = SYSDATE
    WHERE __IDENTIFIER__
});

__PACKAGE__->set_sql(set_date_modified_sysdate => qq{
   UPDATE __TABLE__
      SET  date_modified = SYSDATE
    WHERE __IDENTIFIER__
});


# -------------------------------------------------------------------
package dicty::DB::Stock_center_inventory;
use base 'dicty::DB::DBI';
use Class::DBI::Pager;

dicty::DB::Stock_center_inventory->set_up_table('Stock_center_inventory');


# -------------------------------------------------------------------
package dicty::DB::Strain_gene_link;
use base 'dicty::DB::DBI';
use Class::DBI::Pager;

dicty::DB::Strain_gene_link->set_up_table('Strain_gene_link');


# -------------------------------------------------------------------
package dicty::DB::Plasmid_gene_link;
use base 'dicty::DB::DBI';
use Class::DBI::Pager;

dicty::DB::Plasmid_gene_link->set_up_table('plasmid_gene_link');


# -------------------------------------------------------------------
package dicty::DB::Stock_order;
use base 'dicty::DB::DBI';
use Class::DBI::Pager;

dicty::DB::Stock_order->set_up_table('Stock_order');


# -------------------------------------------------------------------
package dicty::DB::Stock_item_order;
use base 'dicty::DB::DBI';
use Class::DBI::Pager;

dicty::DB::Stock_item_order->set_up_table('Stock_item_order');


# -------------------------------------------------------------------
package dicty::DB::Phenotype;
use base 'dicty::DB::DBI';
use Class::DBI::Pager;

dicty::DB::Phenotype->set_up_table('Phenotype');

# -------------------------------------------------------------------
package dicty::DB::Pathway;
use base 'dicty::DB::DBI';
use Class::DBI::Pager;

dicty::DB::Pathway->set_up_table('Pathway');

# -------------------------------------------------------------------
package dicty::DB::GO;
use base 'dicty::DB::DBI';
use Class::DBI::Pager;

dicty::DB::GO->set_up_table('GO');

# -------------------------------------------------------------------
package dicty::DB::GO_GOSYN;
use base 'dicty::DB::DBI';
use Class::DBI::Pager;

dicty::DB::GO_GOSYN->set_up_table('GO_GOSYN');

# -------------------------------------------------------------------
package dicty::DB::GO_SYNONYM;
use base 'dicty::DB::DBI';
use Class::DBI::Pager;

dicty::DB::GO_SYNONYM->set_up_table('GO_SYNONYM');

# -------------------------------------------------------------------
package dicty::DB::Strain_synonym;
use base 'dicty::DB::DBI';
use Class::DBI::Pager;
use dicty::DBH;
use dicty::Iterator;

dicty::DB::Strain_synonym->set_up_table('Strain_synonym');

sub Search_synonyms_by_strain {
    my ( $self, $query ) = @_;
    my $dbh               = new dicty::DBH();
    my $schema            = dicty::DBH->schema();
    my @data;
    my $strain;

    my $sth = $dbh->prepare( "
        SELECT SS.SYNONYM_ID
        FROM $ENV{'DBUSER'}.STRAIN_SYNONYM SS
        INNER JOIN SYNONYM_ S
        ON SS.SYNONYM_ID = S.SYNONYM_ID
        WHERE SS.STRAIN_ID = ?
        " );

    $sth->execute($query);

     while ( my $row = $sth->fetchrow() ) {
        push( @data, Chado::Synonym->get_single_row( synonym_id => $row ));
    }

     return @data;

}

# -------------------------------------------------------------------
package dicty::DB::Strain_char_cvterm;
use base 'dicty::DB::DBI';
use Class::DBI::Pager;

dicty::DB::Strain_char_cvterm->set_up_table('Strain_char_cvterm');

# -------------------------------------------------------------------
package dicty::DB::Paragraph;
use base 'dicty::DB::DBI';
use Class::DBI::Pager;

dicty::DB::Paragraph->set_up_table('Paragraph');
dicty::DB::Paragraph->sequence(dicty::DB::DBI->owner().'.PARANO_SEQ');

1;

# -------------------------------------------------------------------
package dicty::DB::Template_url;
use base 'dicty::DB::DBI';
use Class::DBI::Pager;

dicty::DB::Template_url->set_up_table('Template_url');
dicty::DB::Template_url->sequence(dicty::DB::DBI->owner().'.TEMPLATE_URL_NO_SEQ');

# -------------------------------------------------------------------
package dicty::DB::Code;
use base 'dicty::DB::DBI';
use Class::DBI::Pager;

dicty::DB::Code->set_up_table('Code');
dicty::DB::Code->sequence(dicty::DB::DBI->owner().'.CODENO_SEQ');


# -------------------------------------------------------------------
package dicty::DB::Locus_gene_info;
use base 'dicty::DB::DBI';
use Class::DBI::Pager;

dicty::DB::Locus_gene_info->set_up_table('Locus_gene_info');


1;



