use strict;
use DictyBaseConfig;
#use Test::More tests=>16;
use Test::More qw/no_plan/;
use Data::Dumper;

use dicty::DB::Adaptor::GBrowse::Chado;

my (@f,$f,@s,$s,$seq1,$seq2);

my $db = eval { dicty::DB::Adaptor::GBrowse::Chado->new() };
ok($db,'Connected to the database');

# there should be one gene named 'abc-1'
@f = $db->get_feature_by_name('test_CURATED');
ok(@f==1, 'Found test_CURATED');

$f = $f[0];
isa_ok($f,"dicty::DB::Adaptor::GBrowse::Segment::Feature", "got right feature");
# there should not be any subfeatures of type "exon" 
ok($f->get_SeqFeatures('exon')==0,'Have not found exons');

#there should be 6 CDS features for both curated and predicted models
is($f->get_SeqFeatures('CDS'), 4, 'Found 4 CDS');

my $s = $db->segment('test_CURATED');
ok(defined $s,'Gene found, created segment');
is($s->start,19490,'Determined start correctly');
is($s->end,22599,'Determined end correctly');

isa_ok($s,"dicty::DB::Adaptor::GBrowse::Segment::Feature",'got right segment');
my @i = $s->features;
ok(@i>0, "Found features");

# the sequence of feature test_curated should match the sequence of the first exon at the
# end (Watson strand)
$seq1 = $f->seq->seq;
#get the first exon
my @objs = sort {$a->start<=>$b->start} $f->get_SeqFeatures('CDS');
$seq2 = $objs[0]->seq->seq;
is(substr($seq1,0,length $seq2),  $seq2, 'The sequence of exon matches test_curated sequence');

# sequence lengths should match
ok(length $seq1 == $f->length, 'Sequence lengths match');

# we should get two objects when we ask for abc-1 using get_features_by_alias
# this also depends on selective subfeature indexing

# test three-tiered genes
($f) = $db->get_feature_by_name('test_cbpD2');
isa_ok($f,'dicty::DB::Adaptor::GBrowse::Segment::Feature', 'got right feature for
test_cbpD2');
my @transcripts = $f->get_SeqFeatures;
is(@transcripts,3, 'Found all transcripts');                                                             
is($transcripts[0]->method,'mRNA','Got mRNA');                                             
is($transcripts[0]->source,'Sequencing Center','Got Sequencing center source');                                


1;

__END__

