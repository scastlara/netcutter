#!/usr/bin/perl
#
#  filter_interactions_to_graph2
#
#    Generates from level 0 (skel) to level MAXLVLS graphs
#    from interating partners with our genes list.
#    Interactions accounted only for human, furthermore
#    intA and intB species must be the same.
#
# ####################################################################
#
#             Copyright (C) 2014/17 - Josep F ABRIL
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
# ####################################################################
#
# $Id: filter_interactions_to_graph2.pl,v 1.1 2018/06/05 14:39:23 jabril Exp jabril $
#
# USAGE:
#
#   filter_interactions_to_graph2.pl  [ options ]        \
#                                     genes_summary.tbl  \
#                                     aliases_file.tbl   \
#                                     destination_prefix \
#                                     dbtype:pairwise_relations_1.tbl \
#                               [ ... dbtype:pairwise_relations_n.tbl ]
#
#   DRIVER genes selected from -> ids:genes_summary.tbl / genes_summary.tbl / ext:genes_summary.tbl
#
use strict;
use warnings;
#
BEGIN{
    use global qw( :Benchmark :ExecReport :CommandLine :GetFH :Exit );
    &init_timer(\@exectime);
}
# use Paths::Graph; ## Hangs on large graphs...
# use Boost::Graph; ## Does not COMPILE...
use Graph;
use Graph::Directed;
use Benchmark;
use Data::Dumper;

#
# VAR DEFS
$PROG = 'filter_interactions_to_graph2.pl';
$VERSION = '1.0';
$USAGE =<<'+++EOH+++';
USAGE:

  filter_interactions_to_graph2.pl  [ options ] \
                              genes_summary.tbl \
                               aliases_file.tbl \
                             destination_prefix \
                dbtype:pairwise_relations_1.tbl \
          [ ... dbtype:pairwise_relations_n.tbl ]


  DRIVER genes selected from -> ids:genes_summary.tbl
                                    genes_summary.tbl
                                ext:genes_summary.tbl


DESCRIPTION:

  Generates from level 0 (skel) to level MAXLVLS graphs from
  interating partners with our genes list.  Interactions accounted
  only for human, furthermore intA and intB species must be the same.


COMMAND-LINE OPTIONS:

+++EOH+++
#

# Main data structures
my %DVgenes  = ();
my %GRAPH    = ();
my %HPARG    = ();
my %SUBGRAPH = ();
my %ALIAS    = ();
my %ALIASDSC = ();
my %UNALIAS  = ();
my %CPA      = (); # to check renaming genes at &norm_gene_id : CPA -> CheckPointAliases
my @IDS      = ();
my @SDI      = ();
my %RIDS     = ();
my $MAXLVLS  = 4; # you have to update @BGCOL accordingly!!!
my $DRAWflg  = 0; # run neato commands or just print them on the STDERR output...

# Network Colors
my @LNCOL = map { '#'.$_ } qw( 000000 888888 CCCCCC ); # black midgrey lightgrey
my @BGCOL = map { '#'.$_ } qw( 007CBA 249EC8 6FAFF9 2FF8F4 CBB0F0 C0EFBA 52E853 0A945C 426A2B );
                             # lvl-4  lvl-3  lvl-2  lvl-1   lvl0  lvl+1  lvl+2  lvl+3  lvl+4
                             # blues(-4:-1) / purple(0) / greens(+1:+4)
my ($DVCOL,$NACOL,$DFCOL) = ('#F1A111','#CCCCCC','#000000'); # orange / lightgrey / black
my @EDGECOL = map { '#'.$_ } qw( FF0000 0000FF 000000 ); # P/G/U on website orange/blue/darkgrey
#
# CMDLINE ARGS
die("### ERROR ### This program requires at least 4 arguments!!!\n".
    "\t\tUSAGE:  filter_interactions_to_graph.pl  genes_summary.tbl hgnc_gene_aliases.tbl destination_prefix  dbtype:pairwise_relations.tbl \n"
    ) if scalar(@ARGV) < 4;
#
# &add_cmdline_opts();
&parse_cmdline();

my ($rpgenesfile, $aliasfile, $outprefix, @interactionsfiles) = @ARGV;

#
# MAIN LOOP
&program_started($PROG);

&read_hgnc_aliases_table($aliasfile, \%ALIAS, \%ALIASDSC, \%CPA);

&read_rpgenes_table($rpgenesfile, \%DVgenes, \%GRAPH, \%HPARG, \%ALIAS, \%ALIASDSC, \%CPA);

foreach my $intfilestr (@interactionsfiles) {

    $intfilestr = 'ihopcsv:'.$intfilestr unless $intfilestr =~ /:/o;

    my ($dbid, $interactionsfile) = split /:/o, $intfilestr, 2;
    $dbid = uc($dbid);

    SWITCH: {

      ($dbid eq 'SPARSER') && do { # no aliases yet for this dataset
	       &read_interactions_table_sparser(  $dbid, $interactionsfile, \%GRAPH, \%HPARG, \%ALIAS, \%ALIASDSC, \%CPA);
	       last SWITCH;
       };

      ($dbid eq 'BIOGRID') && do {
	       &read_interactions_table_biogrid(  $dbid, $interactionsfile, \%GRAPH, \%HPARG, \%ALIAS, \%ALIASDSC, \%CPA);
	       last SWITCH;
       };

      ($dbid eq 'STRING') && do {
	       &read_interactions_table_modstring($dbid, $interactionsfile, \%GRAPH, \%HPARG, \%ALIAS, \%ALIASDSC, \%CPA);
	       last SWITCH;
      };

      ($dbid eq 'PPAXE') && do { # DEFAULT was PPaxe
          &read_interactions_table_ppaxe(   $dbid, $interactionsfile, \%GRAPH, \%HPARG, \%ALIAS, \%ALIASDSC, \%CPA);
          last SWITCH;
      };

      ($dbid eq 'IHOPCSV') && do { # DEFAULT was IHOPCSV
          &read_interactions_table_iHOP(    $dbid, $interactionsfile, \%GRAPH, \%HPARG, \%ALIAS, \%ALIASDSC, \%CPA);
          last SWITCH;
      };

      print STDERR "###############\n### WARNING ### DO NOT KNOW WHAT TO DO with $dbid FORMAT...\n###############\n"
          if $_verbose{'RAW'};

    };
};

&check_aliases(\%ALIAS, \%ALIASDSC, \%UNALIAS);
#>> TRY to UNALIAS on the FLY with UNALIAS
&unalias_graph_ids(\%ALIAS, \%ALIASDSC, \%GRAPH, \%HPARG, \%DVgenes);
# after this we assume there is no redundancy at gene ids level

&write_alias_file($outprefix, \%DVgenes, \%ALIAS, \%ALIASDSC);
&dump_cpa($outprefix,\%CPA) if $_verbose{'DEBUG'};

&save_full_graph($outprefix, \%GRAPH, \%DVgenes, \%ALIASDSC); # only DOT output implemented at this moment

@SDI = @IDS = keys %DVgenes;
# initialize the level zero IDs to DRIVER genes (which have been also checked for aliases)...
foreach my $id (@IDS) {
    $RIDS{$id} = 1;
};

# expand IDS set with those genes connecting DRIVERgenes
&compute_shortests_paths($outprefix, \%GRAPH, \%DVgenes, \@IDS, \@SDI, \%ALIASDSC, \%DVgenes);

for (my $i = 1; $i <= $MAXLVLS; $i++) {
    &build_graph($outprefix,  $i, \%GRAPH, \%HPARG, \%SUBGRAPH, \@IDS, \%RIDS, \%ALIASDSC, \%DVgenes);
};

&program_finished($PROG);
&EXIT('OK');

#
# FUNCTIONS

sub norm_gene_id($$) {
    my ($id, $od, $cpa);
    $od = $id = shift;
    $cpa = shift;
    # From man perlre and considering a complex encoding world (ASCCI/UTF8/locales/and so on)
    #
    # \w [3]  Match a "word" character (alphanumeric plus "_", plus
    #         other connector punctuation chars plus Unicode marks)
    # \W [3]  Match a non-"word" character
    #
    # clean spaces just in case
    $id =~ s/^\s*//og;
    $id =~ s/\s*$//og;
    # FORCE "a" modifier to define \w/\W within ASCII to ensure \w == [A-Za-z0-9_]
    ($id = uc($id)) =~ s/\W+/_/oga;
    # Before: s/[\W_]//og
    #    Now: s/\W+/_/oga
    #    Why? Consider GN1.1 and GN11 as distinct gids,
    #         then GN1_1 != GN11 otherwise GN11 == GN11 .
    #    But question arises now,
    #    are GN1.1 and GN1-1 the same? Let's assume yes...
    # Just adding checkpoint...
    $cpa->{$id}{$od}++;
    return $id;
} # norm_gene_id

sub dump_cpa($$) {
    my $of  = shift;
    my $cpa = shift;
    $of .= '.cpa_alias.dbg';
    open(CPAFH, "> $of") || die("### ERROR ### Cannot open alias debug file: $of\n");
    foreach my $g (keys %$cpa) {
        print CPAFH join("\t",
                         $g,
                         join(" ",
                              map { sprintf("%s[%d]", $_, $cpa->{$g}{$_}) }
                              keys %{ $cpa->{$g} } )
                         ), "\n";
    };
    close(CPAFH);
} # dump_cpa

sub add_aliases($$$@) {
    my ($hsh, $GID, $cpa, @gids) = @_;
    # IMPORTANT: asume that $GID has been already processed with &norm_gene_id
    #            as it has been probably used to define network nodes before looking for aliases
    $GID = &norm_gene_id($GID, $cpa);

    # store an ID as an alias of itself
    exists($hsh->{$GID}) || ($hsh->{$GID} = { $GID => 0 });
    $hsh->{$GID}{$GID}++;

    scalar(@gids) == 0 && return;

    # scalar(@gids) >= 1 -> add many aliases to the ID set of aliases
    foreach my $gid (@gids) {
        $gid = &norm_gene_id($gid, $cpa);
        exists($hsh->{$GID}{$gid}) || ($hsh->{$GID}{$gid} = 0);
        $hsh->{$GID}{$gid}++;
    };

    return;
} # add_aliases

sub check_aliases($$$) {
    my ($alias, $desc, $unalias) = @_;
    my $DEBUG = $_verbose{'DEBUG'};
    my $bar = ("#" x 80)."\n";

    print STDERR $bar, Data::Dumper->Dump([ $alias ], [ qw( *ALIAS-PRE ) ]),"\n", $bar if $DEBUG;

    # initializing projection of aliases "childs" vs reference names "parents"
    %$unalias = ();
    foreach my $lbl (keys %$alias) {
        my @lst = keys %{ $alias->{$lbl} };
        my $numal = scalar(@lst);
        foreach my $syn (@lst) {
            exists($unalias->{$syn}) || ($unalias->{$syn} = []);
# UNCOMMENT THIS AFTER RUN
#            # remove those alias ids that have a main id
#            next if ($syn ne $lbl && exists($desc->{$syn}));
#            #
            push @{ $unalias->{$syn} }, [ $lbl,
                                          exists($desc->{$lbl}) ? 1 : 0 ,
                                          $numal ];
            # if multiple parents: keep the parent with hgnc ($desc) and/or that with more syns ($numal)
        };
    };

    print STDERR $bar, Data::Dumper->Dump([ $unalias ], [ qw( *UNALIAS-PRE ) ]),"\n", $bar if $DEBUG;

    # Attempt to fix redundant "parents"
    foreach my $syn (keys %$unalias) {
        
        (ref($unalias->{$syn}) eq "ARRAY") || next;
        # maybe it has changed on a previous alias rewrite (see next foreach loop)
        # so that we no longer have an array but the corresponding "parent"
        
        my @tmp = sort { $b->[1] <=> $a->[1] ||
                         $b->[2] <=> $a->[2] }
                  @{ $unalias->{$syn} };
        $unalias->{$syn} = $tmp[0][0];
        
        # adding a check for "parents" that are no HGNCs, pointing to a synonim "child",
        # to be referred by the same "parent" as the chosen for the "child"
        scalar(@tmp) > 1 && do {
            my $rary = shift @tmp;
            foreach my $ary (@tmp) {
                (!$ary->[1] && $rary->[1]) && do {
                    $unalias->{$ary->[0]} = $unalias->{$syn};
                };
            };
        };
        
    };
    
    print STDERR $bar, Data::Dumper->Dump([ $unalias ], [ qw( *UNALIAS-POST ) ]),"\n", $bar if $DEBUG;
    
    # Rewriting original aliases for reference names "parent"
    %$alias = ();
    foreach my $syn (keys %{$unalias}) {
        my $par = $unalias->{$syn};
        exists($alias->{$par}) || ($alias->{$par} = {});
        $alias->{$par}{$syn} = 1;
    };
    
    print STDERR $bar, Data::Dumper->Dump([ $alias ], [ qw( *ALIAS-POST ) ]),"\n", $bar if $DEBUG;

} # check_aliases

#### HGNC aliases table  (field separator "\t")
#
# + Official Symbol Records: have a leading 0 on the second field
#     "0A" : standard HUGO identifier.
#     "0U" : not a standard HUGO identifier, i.e. an EnsEMBL gene that does not has a counterpart on HUGO table.
#   for those records, the third field encode the following:
#     [HG] : HGNC ID code.
#     [OT] : OTher information, i.e. full description, gene or protein name, function.
#     [EN] : Standard IUPAC Enzyme Code.
#     [SP] : Species.
#     [AC] : Official EnsGene symbol (Gene name as resulting from BioMART searches).
#
# + Synonym Records: they have the number of referring official names as second field,
#   which are provided as a list on the third field (subfield separator is semicolon ";").
#   Codes used to classify the different official names are:
#     [AC] : Current symbol (first field) is an official HGNC symbol, not a synonym.
#     [PR] : Not an alias but the previous official symbol name, probably deprecated.
#     [SY] : Symbol from first field is a synonym of that ID.
sub read_hgnc_aliases_table($$$$) {
    my ($file, $alias, $desc, $cpa) = @_;
    my $DEBUG = $_verbose{'DEBUG'};

    open(DVFILE, "< $file") || die("### ERROR ### Cannot open DRIVER genes file: $file\n");
    print STDERR "### READING ALIASES DATA from: $file\n" if $_verbose{'RAW'};

    my ($c, $n, $r) = (1, 0, '.');
    while (<DVFILE>) {

        my ($oid,$gid,$cnt,$dat,@dat,%hdat,$cd);
        $r = ".";

        next if /^\s*$/o;
        next if /^\#/o;

        chomp;

        ($oid,$cnt,$dat,undef) = split /\t/o, $_;

        $gid = &norm_gene_id($oid, $cpa);

        print STDERR "### $oid -> $gid : $cnt $dat\n" if $DEBUG;

      SWITCH: {

          $cnt =~ /^0([AU])/o && do {
              my ($d,$k,$ishugo);
              $ishugo = $1 eq "A" ? 1 : 0;
              $dat =~ s/;(\[(?:HG|OT|EN|SP|AC)\])/;\t$1/; # fix required as sometimes subfields are composite
              @dat = split /\t/o, $dat;
              %{ $desc->{$gid} } = ( 'ISHUGO' => $ishugo );
              foreach $d (@dat) {
                  $d =~ s/^\[([^\]]+)\]//o;
                  $k = defined($1) ? $1 : "UN";
                  length($d) > 0 && do {
                      $desc->{$gid}{$k} = $d;
                  };
              };
              &add_aliases($alias,$gid,$cpa);
              $r = "A";
              last SWITCH;
          };

          # $dat =~ s/;(\[(?:AC|PR|SY)\])/;\t$1/; # fix required as sometimes subfields are composite
          @dat = split /;/o, $dat;
          %hdat = ();
          foreach my $d (@dat) {
              $d eq '' && last;
              my ($j, $k); # = ('UN', '???');
              $d =~ /^\[([^\]]+)\](.*)$/o && do {
                  $j = defined($1) ? $1 : 'UN';
                  $k = defined($2) ? $2 : '???';
                  exists($hdat{$j}) || ($hdat{$j} = []);
                  push @{ $hdat{$j} }, $k;
              };
          };

          print STDERR Data::Dumper->Dump([ \%hdat ], [ qw( *hdat ) ]),"\n" if $DEBUG;

          if (exists($hdat{"AC"})) {
              # @{ $dat{"AC"} } = sort { $a cmp $b } @{ $dat{"AC"} }; # just to get always same key if more than one were defined...
              #                                                      # must think how to improve this
              # &add_aliases($alias, $dat{"AC"}[0], $cpa,$gid);
              $cd = "AC";
              $r = "a";
          } elsif (exists($hdat{"PR"})) {
              # @{ $dat{"PR"} } = sort { $a cmp $b } @{ $dat{"PR"} }; # just to get always same key if more than one were defined...
              #                                                       # must think how to improve this
              # &add_aliases($alias, $dat{"PR"}[0], $cpa,$gid);
              $cd = "PR";
              $r = "p";
          } elsif (exists($hdat{"SY"})) {
              # @{ $dat{"SY"} } = sort { $a cmp $b } @{ $dat{"SY"} }; # just to get always same key if more than one were defined...
              #                                                       # must think how to improve this
              # &add_aliases($alias, $dat{"SY"}[0], $cpa,$gid);
              $cd = "SY";
              $r = "s";
          } else {
              $r = "?";
              last SWITCH;
          };

          foreach my $u (@{ $hdat{$cd} }) {
              &add_aliases($alias, $u, $cpa, $gid);
          };

        }; # SWITCH

        print STDERR $r if $_verbose{'RAW'};
        print STDERR "[$c]\n" if ($c % 50 == 0) && $_verbose{'RAW'};
        $c++;

    }; # while <DVFILE>

    print STDERR "[$c]\n" if ($c-- % 50 != 0) && $_verbose{'RAW'};

    close(DVFILE);

    print STDERR "### READ $c RECORDS from $file, aliases table initialized.\n" if $_verbose{'RAW'};

    print STDERR Data::Dumper->Dump([ $alias, $desc ], [ qw( *ALIAS *DESC ) ]),"\n" if $DEBUG;

} # read_hgnc_aliases_table

##
sub write_alias_file($$$$) {
    my ($fileprefix, $rpids, $alias, $adesc, $ofile, %tmp);
    my @IA = qw/ ISHUGO HG AC EN SP OT /;

    ($fileprefix, $rpids, $alias, $adesc) = @_; # $outprefix, \%DVgenes, \%ALIAS

    $ofile = $fileprefix."_IDalias.tbl";
    open(ALAS, "> $ofile") || die("### ERROR ### Cannot open for writing alias file: $ofile\n");
    print STDERR "### WRITING ALIASES TABLE into: $ofile\n" if $_verbose{'RAW'};
    print ALAS '## '.join("\t", qw/ REF_ID DVflg SYNONYMS /, @IA),"\n";

    %tmp = ();
    foreach my $id (keys %$adesc) {
        $tmp{$id} = "REF";
    };
    foreach my $id (keys %$alias) {
        exists($tmp{$id}) || ($tmp{$id} = "SYN", next);
        $tmp{$id} = "BTH"; # if an id apears on both, the longest synonyms list comes from %ALIAS not from %ADESC
    };

    foreach my $id (keys %tmp) {
        my ($rpflg, $synids, $dscstr);

        $rpflg = exists($rpids->{$id}) ? 1 : 0;
        ($synids, $dscstr) = ('', '');

        # remove those alias ids that have a main id
        my @a = grep { $_ !~ /\#\#\#NULL\#\#\#/ } 
                map {
                  my $i = $_;
                  exists($adesc->{$i}) ? '###NULL###' : $i;
                } keys %{ $alias->{$id} };
        my @d = keys %{ $adesc->{$id} };
        
        if ($tmp{$id} eq "BTH") {
            $synids = join(",", @a); # keys %{ $alias->{$id} });
        } elsif ($tmp{$id} eq "REF") {
            $synids = join(",", @d); # keys %{ $adesc->{$id} });
        } else { # $tmp{$id} eq "SYN" already
            $synids = join(",", @a); # keys %{ $alias->{$id} });
        };

        $adesc->{$id}{'ISHUGO'} = exists($adesc->{$id}{'ISHUGO'}) ? $adesc->{$id}{'ISHUGO'} : 0;

        $dscstr = join("\t", map { exists($adesc->{$id})
                                && exists($adesc->{$id}{$_})
                                   ? $adesc->{$id}{$_}
                                   : '-' } @IA);
        
        print ALAS join("\t", $id, $rpflg, $synids, $dscstr),"\n";
        
    };

    close(ALAS);

    print STDERR "### ALIASES TABLE was WRITTEN into $ofile\n" if $_verbose{'RAW'};

} # write_alias_file

# We have to create heys for A and B,
# yet if the B node is a child leave then ADJLST will be empty.
sub init_adjlist($$) {
    my ($href, $gene) = @_;

    exists($href->{$gene}) || do {

        $href->{$gene} = { 'ADJLST' => {} };
        return 1;

    };

    return 0;

} # init_adjlist

sub init_adjnode($$$) {
    my ($href, $giA, $giB) = @_;

    exists($href->{$giA}{'ADJLST'}{$giB}) || do {

        $href->{$giA}{'ADJLST'}{$giB} = { };
        return 1;

    };

    return 0;
} # init_adjnode

sub push_adjnode($$$$$) {
    my ($href, $giA, $giB, $lbl, $str) = @_;

    exists($href->{$giA}{'ADJLST'}{$giB}{$lbl}) || ($href->{$giA}{'ADJLST'}{$giB}{$lbl} = [ 0 ]);

    $href->{$giA}{'ADJLST'}{$giB}{$lbl}[0]++;
    push @{ $href->{$giA}{'ADJLST'}{$giB}{$lbl} }, $str;
    
} # push_adjnode

#### DRIVER genes table (custom made)  #### EXTed DRIVER genes table  #### IDSed DRIVER genes table
#  1 INHERITANCE_CODE                  #  1 INHERITANCE_CODE          #  1 GENE_SYMBOL
#  2 GENE_SYMBOL                       #  2 GENE_SYMBOL
#  3 CHR_ID                            #  3 ALIASES
#  4 LOCUS_START_5'MAX                 #  4 GENBANK_ID
#  5 LOCUS_END_3'MAX                   #  5 REFSEQ_ID
#  6 GENE_STRAND                       #  6 UNIPROT_ID
#  7 GENE_5'                           #  7 ENSEMBL_ID
#  8 GENE_5'_STRAND                    #  8 OMIM_CODE
#  9 GENE_3'                           #  9 GO_CODES (P/C/F)
# 10 GENE_3'_STRAND
# 11 5'MAX_GENE_5'
# 12 3'MAX_GENE_3'
# 13 UCSC_LINK
sub read_rpgenes_table($$$$$$$) {
    my ($file, $rhsh, $hash, $cash, $alias, $adesc, $cpa) = @_;
    my $DEBUG = $_verbose{'DEBUG'};

    my $xflg = ($file =~ s/^ext://o) ? 1 : 0;
    my $sflg = ($file =~ s/^ids://o) ? 1 : 0;

    open(DVFILE, "< $file") || die("### ERROR ### Cannot open DRIVER genes file: $file\n");
    print STDERR "### READING DATA from: $file\n" if $_verbose{'RAW'};

    my ($c, $n) = (1, 0);
    while (<DVFILE>) {

        my (@F, $f, $gid, @flags, $url, @I);

        next if /^\s*$/o;
        next if /^\#/o;

        chomp;

        $sflg && do { # if file contains just ids, few to do

            ($f, undef) = split /\s+/o, $_;

            $gid = &norm_gene_id($f, $cpa);

            &add_aliases($alias, $gid, $cpa);

            exists($rhsh->{$gid}) && do {
                warn("### WARNING ### $gid gene_id is duplicated...\n");
                next;
            };
            
            $rhsh->{$gid} = { 'LVL' => 0, 'URL' => "NOURL" };

            $n += &init_adjlist($hash, $gid);
            &init_adjlist($cash, $gid);

            next;

        };

        @F = split /\t/o, $_;

        print STDERR "### @F\n" if $DEBUG;

        $gid = defined($F[1])  ? $F[1]  : "UNKNOWN";
        $xflg || ($url = defined($F[12]) ? $F[12] : "NOURL");
        @flags = split //, $F[0];

        $gid = &norm_gene_id($gid, $cpa);

        exists($rhsh->{$gid}) && do {
            warn("### WARNING ### $gid gene_id is duplicated...\n");
            next;
        };

        $rhsh->{$gid} = {
            'LVL' => 0,
            'URL' => $url,
            'FLG' => [ @flags[0,1,2,3,4] ]
        };
        # flags for: Autosomal_dominant
        #            Autosomal_recessive
        #            X-Linked
        #            Mitochondrial
        #            Syndromic: 0/non-syndromic  1/can be both  2/always syndromic

        $n += &init_adjlist($hash, $gid);
        &init_adjlist($cash, $gid);

        &add_aliases($alias, $gid, $cpa);
        # exists($alias->{$gid}) || ($alias->{$gid} = { $gid => 0 });

        ($xflg && $F[2] ne '-') && do { # adding aliases for the extended table version

            @I = split /, */o, $F[2];

            &add_aliases($alias, $gid, $cpa, @I);

            #     foreach my $i (@I) {
            #     	# my $g = &norm_gene_id($i, $cpa);
            # 	&add_aliases($alias, $gid, $cpa, &norm_gene_id($i, $cpa));
            # 	# exists($alias->{$gid}) || ($alias->{$g} = { $gid => 0 });
            # 	# $alias->{$gid}{$g}++;
            #     };

        };

    } continue {

        print STDERR "." if $_verbose{'RAW'};
        print STDERR "[$c]\n" if ($c % 50 == 0) && $_verbose{'RAW'};
        $c++;

    }; # while <DVFILE>

    print STDERR "[$c]\n" if ($c-- % 50 != 0) && $_verbose{'RAW'};

    close(DVFILE);

    print STDERR "### READ $c RECORDS from $file, graph initialized with $n empty nodes.\n" if $_verbose{'RAW'};

    print STDERR Data::Dumper->Dump([ $rhsh ], [ qw( *DVgenes ) ]),"\n" if $DEBUG;

} # read_rpgenes_table

#### SENTENCE_PARSER (SPARSER)
#
# This is the general SPARSER format
#
# ID	PMID SENTENCE_NUMBER sub_sentence_number
# PS	Parsed_Tagged_Sentence
# TR	TREE
# VB	verb
# GN	[NA|GID_1 [GID_2 [ ... GID_n]]]
# GP	[NA|GID_1 [GID_2 [ ... GID_n]]]
# LN	[NA|distance_1 [distance_2 [ ... distance_n]]]
# LP	[NA|distance_1 [distance_2 [ ... distance_n]]]
# IC	[0|1|2|3]
# //
#
# But we work over the interactions.tbl produced from that (tab-separated fields)
#
# 1 A->B : Interactors A(SBJ) and B(PRD)
# 2 Verb defining the interaction
# 3 Score (level_SBJ+level_PRD)
# 4 interaction_class
# 5 PubMed ID (PMID)
# 6 Processed sentence
#
sub read_interactions_table_sparser($$$$$$$) {
    my ($dbid, $file, $hash, $cash, $alias, $adesc, $cpa) = @_;
    my $DEBUG = $_verbose{'DEBUG'};

    my ($prevnodesC, $prevnodesP, $prevnodesT, $prevedges) = (&count_nodes($hash), &count_edges($hash)); # scalar(keys %$hash);

    open(SPFILE, "< $file") || die("### ERROR ### Cannot open $dbid network file: $file\n");
    print STDERR "### READING $dbid NETWORK DATA from: $file\n" if $_verbose{'RAW'};

    my ($c,$N,$n) = (1, 0, 0);
    while (<SPFILE>) {

        my ($gid, $gidA, $gidB, $sentence, $verb, $score, $class, $pmid, $lbl);

        next if /^\s*$/o;
        next if /^\#/o;

        chomp;
        ($gid, $verb, $score, $class, $pmid, $sentence) = split /\t/o, $_, 6;
        ($gidA, $gidB) = split /\-\>/o, $gid, 2;

        $gidA = &norm_gene_id($gidA, $cpa);
        $gidB = &norm_gene_id($gidB, $cpa);

        $N += &init_adjlist($hash, $gidA);
        $N += &init_adjlist($hash, $gidB);
        &init_adjlist($cash, $gidA);
        &init_adjlist($cash, $gidB);

        $lbl = '<U>SPARSER|'.$verb; # '<U>' for unknown interaction type

        $n += &init_adjnode($hash,$gidA,$gidB);
        &init_adjnode($cash,$gidB,$gidA);

        &push_adjnode($hash,$gidA,$gidB,$lbl,"SPARSER $score $pmid <z>$sentence</z>");
        &push_adjnode($cash,$gidB,$gidA,$lbl,"SPARSER $score $pmid <z>$sentence</z>");

        # NO ALIASES defined ???
        &add_aliases($alias, $gidA, $cpa);
        &add_aliases($alias, $gidB, $cpa);
        # exists($alias->{$gidA}) || ($alias->{$gidA} = { $gidA => 0 });
        # exists($alias->{$gidB}) || ($alias->{$gidB} = { $gidB => 0 });
        # $alias->{$gidA}{$gidA}++;
        # $alias->{$gidB}{$gidB}++;

        print STDERR "." if $_verbose{'RAW'};
        print STDERR "[$c]\n" if ($c % 100 == 0) && $_verbose{'RAW'};
        $c++;

    }; # while <DVFILE>

    print STDERR "[$c]\n" if ($c-- % 100 != 0) && $_verbose{'RAW'};

    close(SPFILE);

    my ($thynodesC, $thynodesP, $thynodesT, $thyedges) = (&count_nodes($hash), &count_edges($hash));
    print STDERR "### READ $c $dbid RELATIONSHIPS from $file\n",
                 "##--> $dbid : $N new NODES and $n new EDGES, from $c records read.\n",
                 sprintf("##--> $dbid : NODES %d child %d parent / %d prev + %d new = %d total",
                         $thynodesC, $thynodesP, $prevnodesT, $thynodesT - $prevnodesT, $thynodesT),
                 sprintf(           " : EDGES %d prev + %d new = %d total\n",
                                    $prevedges, $thyedges - $prevedges, $thyedges)
                     if $_verbose{'RAW'};

    print STDERR Data::Dumper->Dump([ $hash ], [ qw( *GRAPH ) ]),"\n" if $DEBUG;

} # read_interactions_table_sparser

#### SENTENCE_PARSER (PPaxe)
#
# This is the general layout of ppaxe:
#
# PMID	Pubmed ID number
# GN1	 Gene 1
# GN2	 Gene 2
# SC	Score
# ST	 Sentence where the supposed interaction was found
# //
#
# But we decided to filter the sentence out for only the verbs indicating interactions.
#
# VERB	The verb indicating the interaction
#
sub read_interactions_table_ppaxe($$$$$$$) {
    my ($dbid, $file, $hash, $cash, $alias, $adesc, $cpa) = @_;
    my $DEBUG = $_verbose{'DEBUG'};

    my ($prevnodesC, $prevnodesP, $prevnodesT, $prevedges) = (&count_nodes($hash), &count_edges($hash)); # scalar(keys %$hash);

    open(DVFILE, "< $file") || die("### ERROR ### Cannot open $dbid network file: $file\n");
    print STDERR "### READING $dbid NETWORK DATA from: $file\n" if $_verbose{'RAW'};

    my ($c,$N,$n) = (1, 0, 0);
    while (<DVFILE>) {

        my ($pmid, $gidA, $gidB, $score, $sentence, $verb, $lbl);
        #    my ($pmid, $gidA, $gidB, $score, $verb, tverb, $lbl);
        next if /^\s*$/o;
        next if /^\#/o;

        chomp;
        ($pmid, $gidA, $gidB, $score, $sentence) = split /\t/o, $_, 5;
        #   ($pmid, $gidA, $gidB, $score, $tverb, $lbl) = split /\t/o, $_, 6;
        $gidA = &norm_gene_id($gidA, $cpa);
        $gidB = &norm_gene_id($gidB, $cpa);

        $N += &init_adjlist($hash, $gidA);
        $N += &init_adjlist($hash, $gidB);
        &init_adjlist($cash, $gidA);
        &init_adjlist($cash, $gidB);

        $lbl = '<U>PPaxe';  # '<U>' for unknown interaction type
        #    $lbl = "PPaxe".'|'.$verb;

        $n += &init_adjnode($hash,$gidA,$gidB);
        &init_adjnode($cash,$gidB,$gidA);

        &push_adjnode($hash,$gidA,$gidB,$lbl,"PPaxe $score $pmid <z>$sentence</z>");
        &push_adjnode($cash,$gidB,$gidA,$lbl,"PPaxe $score $pmid <z>$sentence</z>");

        # NO ALIASES defined ???
        &add_aliases($alias, $gidA, $cpa);
        &add_aliases($alias, $gidB, $cpa);
        # exists($alias->{$gidA}) || ($alias->{$gidA} = { $gidA => 0 });
        #  exists($alias->{$gidB}) || ($alias->{$gidB} = { $gidB => 0 });
        # $alias->{$gidA}{$gidA}++;
        # $alias->{$gidB}{$gidB}++;

        print STDERR "." if $_verbose{'RAW'};
        print STDERR "[$c]\n" if ($c % 100 == 0) && $_verbose{'RAW'};
        $c++;

    }; # while <DVFILE>

    print STDERR "[$c]\n" if ($c-- % 100 != 0) && $_verbose{'RAW'};

    close(DVFILE);

    my ($thynodesC, $thynodesP, $thynodesT, $thyedges) = (&count_nodes($hash), &count_edges($hash));
    print STDERR "### READ $c $dbid RELATIONSHIPS from $file\n",
                 "##--> $dbid : $N new NODES and $n new EDGES, from $c records read.\n",
                 sprintf("##--> $dbid : NODES %d child %d parent / %d prev + %d new = %d total",
                         $thynodesC, $thynodesP, $prevnodesT, $thynodesT - $prevnodesT, $thynodesT),
                 sprintf(           " : EDGES %d prev + %d new = %d total\n",
                                    $prevedges, $thyedges - $prevedges, $thyedges)
                     if $_verbose{'RAW'};

    print STDERR Data::Dumper->Dump([ $hash ], [ qw( *GRAPH ) ]),"\n" if $DEBUG;

} # read_interactions_table_ppaxe

#### BioGRID input data (http://wiki.thebiogrid.org/doku.php/biogrid_tab_version_2.0)
#
# The column contents of BioGRID Tab 2.0 files should be as follows:
#
#  1 BioGRID Interaction ID. A unique identifier for each interaction within the BioGRID database.
#  2 Entrez Gene ID for Interactor A. The identifier from the Entrez-Gene database that corresponds to Interactor A.
#  3 Entrez Gene ID for Interactor B. Same structure as column 2.
#  4 BioGRID ID for Interactor A. The identifier in the BioGRID database that corresponds to Interactor A. These identifiers are best used for creating links to the BioGRID from your own websites or applications. To link to a page within our site, simply append the URL: http://www.thebiogrid.org/ID/ to each ID. For example, http://www.thebiogrid.org/31623/.
#  5 BioGRID ID for Interactor B. Same structure as column 4.
#  6 Systematic name for Interactor A. A plain text systematic name if known for interactor A. Will be a ”-” if no name is available.
#  7 Systematic name for Interactor B. Same structure as column 6.
#  8 Official symbol for Interactor A. A common gene name/official symbol for interactor A. Will be a ”-” if no name is available.
#  9 Official symbol for Interactor B. Same structure as column 8.
# 10 Synonyms/Aliases for Interactor A. A “|” separated list of alternate identifiers for interactor A. Will be ”-” if no aliases are available.
# 11 Synonyms/Aliases for Interactor B. Same stucture as column 10.
# 12 Experimental System Name. One of the many Experimental Evidence Codes supported by the BioGRID.
# 13 Experimental System Type. This will be either “physical” or “genetic” as a classification of the Experimental System Name.
# 14 First author surname of the publication in which the interaction has been shown, optionally followed by additional indicators, e.g. Stephenson A (2005)
# 15 Pubmed ID of the publication in which the interaction has been shown.
# 16 Organism ID for Interactor A. This is the NCBI Taxonomy ID for Interactor A.
# 17 Organism ID for Interactor B. Same structure as 16.
# 18 Interaction Throughput. This will be either High Throughput, Low Throughput or Both (separated by “|”).
# 19 Quantitative Score. This will be a positive for negative value recorded by the original publication depicting P-Values, Confidence Score, SGA Score, etc. Will be ”-” if no score is reported.
# 20 Post Translational Modification. For any Biochemical Activity experiments, this field will be filled with the associated post translational modification. Will be ”-” if no modification is reported.
# 21 Phenotypes. If any phenotype info is recorded, it will be provided here separated by “|”. Each phenotype will be of the format <phenotype>[<phenotype qualifier>]:<phenotype type>. Note that the phenotype types and qualifiers are optional and will only be present where recorded. Phenotypes may also have multiple qualifiers in which case unique qualifiers will be separated by carat (^). If no phenotype information is available, this field will contain ”-”.
# 22 Qualifications. If additional plain text information was recorded for an interaction, it will be listed with unique qualifiers separated by “|”. If no qualification is available, this field will contain ”-”.
# 23 Tags. If an interaction has been tagged with additional classifications, they will be provided in this column separated by “|”. If no tag information is available, this field will contain ”-”.
# 24 Source Database. This field will contain the name of the database in which this interaction was provided.
#
# NOTE: Consider that we assume that the BioGRID database interactions are "directional"
#       (so that, if A interacts with B, perhaps B interacts with A,
#             but if A regulates B, B is not regulating A).
#       Thus, we do not keep record of the reciprocal relations when loading interactions on %GRAPH.
#
sub read_interactions_table_biogrid($$$$$$$) {
    my ($dbid, $file, $hash, $cash, $alias, $adesc, $cpa) = @_;
    my $DEBUG = $_verbose{'DEBUG'};

    my %BGI = ( # https://wiki.thebiogrid.org/doku.php/experimental_systems
                'AFFINITY CAPTURE-LUMINESCENCE' => 'P', # Physical Interactions
                'AFFINITY CAPTURE-MS'           => 'P',
                'AFFINITY CAPTURE-RNA'          => 'P',
                'AFFINITY CAPTURE-WESTERN'      => 'P',
                'BIOCHEMICAL ACTIVITY'          => 'P',
                'CO-CRYSTAL STRUCTURE'          => 'P',
                'CO-FRACTIONATION'              => 'P',
                'CO-LOCALIZATION'               => 'P',
                'CO-PURIFICATION'               => 'P',
                'FAR WESTERN'                   => 'P',
                'FRET'                          => 'P',
                'PCA'                           => 'P',
                'PROTEIN-PEPTIDE'               => 'P',
                'PROTEIN-RNA'                   => 'P',
                'PROXIMITY LABEL-MS'            => 'P',
                'RECONSTITUTED COMPLEX'         => 'P',
                'TWO-HYBRID'                    => 'P',
                'DOSAGE GROWTH DEFECT'          => 'G', # Genetic Interactions
                'DOSAGE LETHALITY'              => 'G',
                'DOSAGE RESCUE'                 => 'G',
                'NEGATIVE GENETIC'              => 'G',
                'PHENOTYPIC ENHANCEMENT'        => 'G',
                'PHENOTYPIC SUPPRESSION'        => 'G',
                'POSITIVE GENETIC'              => 'G',
                'SYNTHETIC GROWTH DEFECT'       => 'G',
                'SYNTHETIC HAPLOINSUFFICIENCY'  => 'G',
                'SYNTHETIC LETHALITY'           => 'G',
                'SYNTHETIC RESCUE'              => 'G', # Keys up   from column: Experimental System
                'UNKNOWN'                       => 'U',
                'PHYSICAL'                      => 'P',	# Keys down from column: Experimental System Type
                'GENETIC'                       => 'G'
        );
    
    my ($prevnodesC, $prevnodesP, $prevnodesT, $prevedges) = (&count_nodes($hash), &count_edges($hash)); # scalar(keys %$hash);

    open(DVFILE, "< $file") || die("### ERROR ### Cannot open $dbid network file: $file\n");
    print STDERR "### READING $dbid NETWORK DATA from: $file\n" if $_verbose{'RAW'};

    my ($c,$N,$n) = (1, 0, 0);
    while (<DVFILE>) {

        my ($gidA, $gidB, $aliasA, $aliasB, $expersys, $expertype, $specA, $specB, $pmid, $score, $lbl, $tplbl);

        next if /^\s*$/o;
        next if /^\#/o;

        chomp;

        (undef, undef, undef, undef, undef, undef, undef,
         $gidA, $gidB, $aliasA, $aliasB, $expersys, $expertype,
         undef, $pmid, $specA, $specB, undef, $score, undef) = split /\t/o, $_, 20;

        # Check for human (sp_code=9606) and specA==specB (both prot/genes from the same species)
        next if ($specA != $specB || $specA != 9606);

        print STDERR "### $gidA($aliasA) vs $gidB($aliasB) $expersys $expertype $specA==$specB\n" if $DEBUG;

        $gidA = &norm_gene_id($gidA, $cpa);
        $gidB = &norm_gene_id($gidB, $cpa);

        $N += &init_adjlist($hash, $gidA);
        $N += &init_adjlist($hash, $gidB);
        &init_adjlist($cash, $gidA);
        &init_adjlist($cash, $gidB);

        my $ET = uc($expersys); # uc($expertype);
        $tplbl = exists($BGI{$ET}) ? $BGI{$ET} : $BGI{'UNKNOWN'};
        $lbl = '<'.$tplbl.'>'.$expersys.'|'.$expertype;

        $n += &init_adjnode($hash,$gidA,$gidB);
        &init_adjnode($cash,$gidB,$gidA);

        &push_adjnode($hash,$gidA,$gidB,$lbl,"BIOGRID $score $pmid");
        &push_adjnode($cash,$gidB,$gidA,$lbl,"BIOGRID $score $pmid");

        if ($aliasA ne '-') {
            my @A = split /\|/, $aliasA;

            &add_aliases($alias, $gidA, $cpa, @A);
            # foreach my $A (@A, $gidA) {
            # 	$A = &norm_gene_id($A, $cpa);
            # 	exists($alias->{$gidA}) || ($alias->{$gidA} = { $gidA => 0 });
            # 	exists($alias->{$gidA}{$A}) || ($alias->{$gidA}{$A} = 0);
            # 	$alias->{$gidA}{$gidA}++;
            # 	$alias->{$gidA}{$A}++;
            # };
        };
        if ($aliasB ne '-') {
            my @B = split /\|/, $aliasB;

            &add_aliases($alias, $gidB, $cpa, @B);
            # foreach my $B (@B, $gidB) {
            # 	$B = &norm_gene_id($B, $cpa);
            # 	exists($alias->{$gidB}) || ($alias->{$gidB} = { $gidB => 0 });
            # 	exists($alias->{$gidB}{$B}) || ($alias->{$gidB}{$B} = 0);
            # 	$alias->{$gidB}{$gidB}++;
            # 	$alias->{$gidB}{$B}++;
            # };
        };

        print STDERR "." if $_verbose{'RAW'};
        print STDERR "[$c]\n" if ($c % 100 == 0) && $_verbose{'RAW'};
        $c++;

    }; # while <DVFILE>

    print STDERR "[$c]\n" if ($c-- % 100 != 0) && $_verbose{'RAW'};

    close(DVFILE);

    my ($thynodesC, $thynodesP, $thynodesT, $thyedges) = (&count_nodes($hash), &count_edges($hash));
    print STDERR "### READ $c $dbid RELATIONSHIPS from $file\n",
                 "##--> $dbid : $N new NODES and $n new EDGES, from $c records read.\n",
                 sprintf("##--> $dbid : NODES %d child %d parent / %d prev + %d new = %d total",
                         $thynodesC, $thynodesP, $prevnodesT, $thynodesT - $prevnodesT, $thynodesT),
                 sprintf(           " : EDGES %d prev + %d new = %d total\n",
                                    $prevedges, $thyedges - $prevedges, $thyedges)
                     if $_verbose{'RAW'};

    print STDERR Data::Dumper->Dump([ $hash ], [ qw( *GRAPH ) ]),"\n" if $DEBUG;

} # read_interactions_table_biogrid

#### STRING input data
#
# The column contents of STRING files after fixing gene identifiers should be as follows:
#
#  1 Interactor A
#  2 Interactor B
#  3 Interaction type
#  4 Interaction Score
#  5 IsBidirectional flag ### CHANGED INPUT FORMAT ###
#  6 Evidences: a whitespace separated list of pubmed/interaction/pathway/etc database ids
#
#  6.old Database/s: a  whitespace separated list of interaction/pathway/etc databases (if empty, interaction only described in STRING)
# EXAMPLE:  FKBP4 <\t> FLJ31884 <\t> binding <\t> 992 <\t> t <\t> grid kegg_pathways mint intact
##
##TODO fix input file function
sub read_interactions_table_modstring($$$$$$$) {
    my ($dbid, $file, $hash, $cash, $alias, $adesc, $cpa) = @_;
    my $DEBUG = $_verbose{'DEBUG'};

    my ($prevnodesC, $prevnodesP, $prevnodesT, $prevedges) = (&count_nodes($hash), &count_edges($hash)); # scalar(keys %$hash);

    open(DVFILE, "< $file") || die("### ERROR ### Cannot open $dbid network file: $file\n");
    print STDERR "### READING $dbid NETWORK DATA from: $file\n" if $_verbose{'RAW'};

    my ($c,$N,$n, $mo, $bi) = (1, 0, 0, 0, 0);
    while (<DVFILE>) {

        my ($gidA, $gidB, $expertype, $score, $bidirflag, $sources, $lbl);

        next if /^\s*$/o;
        next if /^\#/o;

        chomp;

        ($gidA, $gidB, $expertype, $score, $bidirflag, $sources) = split /\t/o, $_;

        $gidA = &norm_gene_id($gidA, $cpa);
        $gidB = &norm_gene_id($gidB, $cpa);

        $N += &init_adjlist($hash, $gidA);
        $N += &init_adjlist($hash, $gidB);
        &init_adjlist($cash, $gidA);
        &init_adjlist($cash, $gidB);

        $lbl = '<P>'.$expertype; # assuming all <P>hysical?

        $n += &init_adjnode($hash,$gidA,$gidB);
        &init_adjnode($cash,$gidB,$gidA);

        &push_adjnode($hash,$gidA,$gidB,$lbl,"STRING $score $sources");
        &push_adjnode($cash,$gidB,$gidA,$lbl,"STRING $score $sources");

        uc($bidirflag) eq 'T' && do { # adding reverse path if interaction is set as bidirectional in STRING

            $n += &init_adjnode($hash,$gidB,$gidA);
            &init_adjnode($cash,$gidA,$gidB);

            &push_adjnode($hash,$gidB,$gidA,$lbl,"STRING $score $sources");
            &push_adjnode($cash,$gidA,$gidB,$lbl,"STRING $score $sources");

            $bi++;
        };

        # NO ALIASES defined ???
        &add_aliases($alias, $gidA, $cpa);
        &add_aliases($alias, $gidB, $cpa);
        # exists($alias->{$gidA}) || ($alias->{$gidA} = { $gidA => 0 });
        # exists($alias->{$gidB}) || ($alias->{$gidB} = { $gidB => 0 });
        # $alias->{$gidA}{$gidA}++;
        # $alias->{$gidB}{$gidB}++;

        print STDERR "." if $_verbose{'RAW'};
        print STDERR "[$c]\n" if ($c % 100 == 0) && $_verbose{'RAW'};
        $c++;

    }; # while <DVFILE>

    print STDERR "[$c]\n" if ($c-- % 100 != 0) && $_verbose{'RAW'};

    close(DVFILE);

    $mo = $c - $bi;  

    my ($thynodesC, $thynodesP, $thynodesT, $thyedges) = (&count_nodes($hash), &count_edges($hash));
    print STDERR "### READ $c $dbid RELATIONSHIPS from $file\n",
                 "##--> Total $c : $mo monodirectional + $bi bidirectional.\n",
                 "##--> $dbid : $N new NODES and $n new EDGES, from $c records read.\n",
                 sprintf("##--> $dbid : NODES %d child %d parent / %d prev + %d new = %d total",
                         $thynodesC, $thynodesP, $prevnodesT, $thynodesT - $prevnodesT, $thynodesT),
                 sprintf(           " : EDGES %d prev + %d new = %d total\n",
                                    $prevedges, $thyedges - $prevedges, $thyedges)
                     if $_verbose{'RAW'};

    print STDERR Data::Dumper->Dump([ $hash ], [ qw( *GRAPH ) ]),"\n" if $DEBUG;

} # read_interactions_table_modstring

#### iHOP input data
#
# The column contents of iHOP manually curated files should be as follows:
#
#  1 Interaction LEVEL
#  2 Interaction SUBLEVEL
#  3 Functional description (ACTION)
#  4 PARTNER_A
#  5 PARTNER_B
#  6 SYNONYMS_PARTNER_A
#  7 SYNONYMS_PARTNER_B
#  8 SNPs_SUBGRAPH
#  9 DISEASE_IMPLICATION_SUBGRAPH
# 10 ALLELIC_VARIANTS
# 11 OMIM_LINK
# 12 PUBMED_ID
#
sub read_interactions_table_iHOP($$$$$$$) {
    my ($dbid, $file, $hash, $cash, $alias, $adesc, $cpa) = @_;
    my $DEBUG = $_verbose{'DEBUG'};

    my ($prevnodesC, $prevnodesP, $prevnodesT, $prevedges) = (&count_nodes($hash), &count_edges($hash)); # scalar(keys %$hash);

    open(DVFILE, "< $file") || die("### ERROR ### Cannot open $dbid network file: $file\n");
    print STDERR "### READING $dbid NETWORK DATA from: $file\n" if $_verbose{'RAW'};

    my ($c,$N,$n) = (1, 0, 0);
    while (<DVFILE>) {

        my ($gidA, $gidB, $aliasA, $aliasB, $expersys, $expertype, $pmid, $lbl, $pr);

        next if /^\s*$/o;
        next if /^\#/o;

        chomp;

        ($expersys, $expertype, undef,
         $gidA, $gidB, $aliasA, $aliasB,
         undef, undef, undef, undef, $pmid) = split /\t/o, $_;

        $pr = 0;

        $gidA ne '-' && do {
            $gidA = &norm_gene_id($gidA, $cpa);
            $N += &init_adjlist($hash, $gidA);
            &init_adjlist($cash, $gidA);
            $pr++;
        };

        $gidB ne '-' && do {
            $gidB = &norm_gene_id($gidB, $cpa);
            $N += &init_adjlist($hash, $gidB);
            &init_adjlist($cash, $gidB);
            $pr++;
        };

        $pr == 2 && do {
            $lbl = '<P>'.$expersys.'|'.$expertype; # assuming all <P>hysical?
                   # $SNPs."|".$diseases."|".$OMIM_VAR;

            $n += &init_adjnode($hash,$gidA,$gidB);
            &init_adjnode($cash,$gidB,$gidA);

            &push_adjnode($hash,$gidA,$gidB,$lbl,"IHOP hand-curated $pmid");
            &push_adjnode($cash,$gidB,$gidA,$lbl,"IHOP hand-curated $pmid");
        };

        if ($aliasA ne '-') {
            my @A = split /\|/, $aliasA;

            &add_aliases($alias, $gidA, $cpa, @A);
            # foreach my $A (@A, $gidA) {
            # 	$A = &norm_gene_id($A, $cpa);
            # 	exists($alias->{$gidA}) || ($alias->{$gidA} = {});
            # 	exists($alias->{$gidA}{$A}) || ($alias->{$gidA}{$A} = 0);
            # 	$alias->{$gidA}{$gidA}++;
            # 	$alias->{$gidA}{$A}++;
            # };
        };
        if ($aliasB ne '-') {
            my @B = split /\|/, $aliasB;

            &add_aliases($alias, $gidB, $cpa, @B);
            # foreach my $B (@B, $gidB) {
            # 	$B = &norm_gene_id($B, $cpa);
            # 	exists($alias->{$gidB}) || ($alias->{$gidB} = {});
            # 	exists($alias->{$gidB}{$B}) || ($alias->{$gidB}{$B} = 0);
            # 	$alias->{$gidB}{$gidB}++;
            # 	$alias->{$gidB}{$B}++;
            # };
        };

        print STDERR "." if $_verbose{'RAW'};
        print STDERR "[$c]\n" if ($c % 100 == 0) && $_verbose{'RAW'};
        $c++;

    }; # while <DVFILE>

    print STDERR "[$c]\n" if ($c-- % 100 != 0) && $_verbose{'RAW'};

    close(DVFILE);

    my ($thynodesC, $thynodesP, $thynodesT, $thyedges) = (&count_nodes($hash), &count_edges($hash));
    print STDERR "### READ $c $dbid RELATIONSHIPS from $file\n",
                 "##--> $dbid : $N new NODES and $n new EDGES, from $c records read.\n",
                 sprintf("##--> $dbid : NODES %d child %d parent / %d prev + %d new = %d total",
                         $thynodesC, $thynodesP, $prevnodesT, $thynodesT - $prevnodesT, $thynodesT),
                 sprintf(           " : EDGES %d prev + %d new = %d total\n",
                                    $prevedges, $thyedges - $prevedges, $thyedges)
                     if $_verbose{'RAW'};

    print STDERR Data::Dumper->Dump([ $hash ], [ qw( *GRAPH ) ]),"\n" if $DEBUG;

} # read_interactions_table_iHOP

#
# generating graphs at different levels...
sub build_graph($$$$$$$$$) {
    my ($fileprefix, $level, $graph, $hparg, $subgraph, $ids, $rids, $adesc, $DVgns) = @_;
    my $DEBUG = $_verbose{'DEBUG'};
    my %STATUS = ( 'FOUND' => {}, 'ALIAS' => {}, 'MISSING' => {}, 'SUBGRAPH' => {} );
    my %GNG = ();

    my $numlvl = sprintf("%s", ($level < 0 ? "-" : "+").abs($level));
    $STATUS{'SUBGRAPH'} = { map { $_ => 0 } keys %$subgraph };

    my ($fullnodesC, $fullnodesP, $fullnodesT, $fulledges,
        $prevnodesC, $prevnodesP, $prevnodesT, $prevedges
        ) = (&count_nodes($graph),    &count_edges($graph),
             &count_nodes($subgraph), &count_edges($subgraph)); # scalar(keys %$hash);

    ## SUBGRAPH

    # First we need to extract %SUBGRAPH from %GRAPH by @IDS
    printf STDERR "### LEVEL %s: FILTERING SUBGRAPH DATA\n", $numlvl if $_verbose{'RAW'};

    my @thyids = @$ids;

    my $c = 0;
    my $x = '-'; # - is missing / + is found
    foreach my $id (@thyids) {

        # $id = &norm_gene_id($id, $cpa); # NOT needed, this is performed each time a new gene is processed from input files

        my @Cn = ();
        my @Pn = ();

        if (exists($graph->{$id}) || exists($hparg->{$id})) {

            $x = '+';
            $STATUS{'FOUND'}{$id}++;

            @Cn = keys %{ $graph->{$id}{'ADJLST'} } if exists($graph->{$id});
            @Pn = keys %{ $hparg->{$id}{'ADJLST'} } if exists($hparg->{$id});

            # NOTE: ALIASES have been previously removed using &compacting_graph()
            # } elsif (exists($alias->{$id})) {
            #     my $fnd = 0;
            #     foreach my $alid (keys %{ $alias->{$id} }) {
            # 	# look for aliases, else missing... implement aliases later or build GRAPH based on main ID...
            #     };
            #     $x = ':';
            #     $STATUS{'ALIAS'}{$id}++;
        } else {
            $x = '-';
            $STATUS{'MISSING'}{$id}++;
            next;
        };

        exists($subgraph->{$id}) || do {
            $subgraph->{$id}{'ADJLST'} = {};
            $subgraph->{$id}{'ALIASES'} = $graph->{$id}{'ALIASES'};
            $subgraph->{$id}{'LVL'} = undef; # exists($rids->{$id}) ? 0 : $level;
            # we do not know a priory if this $id will have parent or child nodes
            exists($GNG{$id}) || ($GNG{$id} = { "C" => {}, "P" => {} });
        };

        my ($numC,$numP) = ( scalar(@Cn), scalar(@Pn) );
        ($numC + $numP != 0 && !defined($subgraph->{$id}{'LVL'}))
            && ($subgraph->{$id}{'LVL'} = (exists($rids->{$id}) ? 0 : $level));

        # look for the child nodes
        foreach my $cn (@Cn) {

            exists($subgraph->{$cn}) || do {
                $subgraph->{$cn}{'ADJLST'} = {};
                $subgraph->{$cn}{'ALIASES'} = $graph->{$cn}{'ALIASES'};
                $subgraph->{$cn}{'LVL'} = exists($rids->{$cn}) ? 0 : $level;
            };

            exists($subgraph->{$id}{'ADJLST'}{$cn}) || do {
                $subgraph->{$id}{'ADJLST'}{$cn} = $graph->{$id}{'ADJLST'}{$cn};
                # already def: $subgraph->{$id}{'LVL'} = exists($rids->{$id}) ? 0 : $level;
                exists($GNG{$cn}) || ($GNG{$cn} = { "C" => {}, "P" => {} });
                $GNG{$id}{"C"}{$cn}++;
                $GNG{$cn}{"P"}{$id}++;
            };

        };

        # look for the parent nodes
        foreach my $pn (@Pn) {

            exists($subgraph->{$pn}) || do {
                $subgraph->{$pn}{'ADJLST'} = {};
                $subgraph->{$pn}{'ALIASES'} = $graph->{$pn}{'ALIASES'};
                $subgraph->{$pn}{'LVL'} = exists($rids->{$pn}) ? 0 : -$level;
            };

            exists($subgraph->{$pn}{'ADJLST'}{$id}) || do {
                $subgraph->{$pn}{'ADJLST'}{$id} = $graph->{$pn}{'ADJLST'}{$id};
                exists($GNG{$pn}) || ($GNG{$pn} = { "C" => {}, "P" => {} });
                $GNG{$pn}{"C"}{$id}++;
                $GNG{$id}{"P"}{$pn}++;
            };

        };

        print STDERR $x if $_verbose{'RAW'};
        print STDERR "[$c]\n" if (++$c % 50 == 0) && $_verbose{'RAW'};

    }; # foreach $id

    print STDERR "[$c]\n" if ($c % 50 != 0) && $_verbose{'RAW'};
    $STATUS{'FOUND'}    = scalar(keys %{ $STATUS{'FOUND'}    });
    $STATUS{'MISSING'}  = scalar(keys %{ $STATUS{'MISSING'}  });
    $STATUS{'SUBGRAPH'} = scalar(keys %{ $STATUS{'SUBGRAPH'} });

    my ($thynodesC, $thynodesP, $thynodesT, $thyedges) = (&count_nodes($subgraph), &count_edges($subgraph));
    printf STDERR "### LEVEL %s: From %d IDS, %d were found, %d were missing, %d predefined\n".
        "### LEVEL %s: NODES %d prev + %d new = %d total from %d / %d child + %d parent from %d child + %d parent".
        " : EDGES %d prev + %d new = %d total from %d.\n",
        $numlvl, scalar(@thyids),
        $STATUS{'FOUND'}, $STATUS{'MISSING'}, $STATUS{'SUBGRAPH'},
        $numlvl, $prevnodesT, $thynodesT - $prevnodesT, $thynodesT, $fullnodesT,
        $thynodesC, $thynodesP, $fullnodesC, $fullnodesP,
        $prevedges, $thyedges - $prevedges, $thyedges, $fulledges
        if $_verbose{'RAW'};

    ## OUTPUT

    # Save interations to file + expand IDS
    my $ofile = $fileprefix."_graph_lvl".$numlvl.".dot";
    my $Ofile = $fileprefix."_graph_lvl".$numlvl."_split.dot";
    my $gfile = $fileprefix."_graph_lvl".$numlvl.".graphml";
    my $jfile = $fileprefix."_graph_lvl".$numlvl.".json";
    my $xfile = $fileprefix."_graph_web_lvl".$numlvl.".json";

    printf STDERR "### LEVEL %s: WRITING GRAPH DATA into: %s\n", $numlvl, $ofile if $_verbose{'RAW'};
    open(DOTFILE, "> $ofile") || die("### ERROR ### Cannot open dot(lvl:$numlvl) file: $ofile\n");
    open(DOSFILE, "> $Ofile") || die("### ERROR ### Cannot open dot(lvl:$numlvl) split file: $Ofile\n");
    open(XMLFILE, "> $gfile") || die("### ERROR ### Cannot open graphml(lvl:$numlvl) file: $gfile\n");
    open(JSNFILE, "> $jfile") || die("### ERROR ### Cannot open json(lvl:$numlvl) file: $jfile\n");

    # EXTJSN is "easy" as it depends only on %GNG
    my $jstr = '';

    foreach my $g (keys %GNG) {
        my $thylvl = (exists($subgraph->{$g}) && defined($subgraph->{$g}{'LVL'})) ? $MAXLVLS + $subgraph->{$g}{'LVL'} : undef;
        my $thycol = (defined($thylvl)
                      ? $BGCOL[ $thylvl ]
                      : (exists($rids->{$g}) ? $DVCOL : $NACOL));
        $jstr .= ($jstr ne q{} ? ",\n" : '') .
            &json_node_ext($g, $GNG{$g}{"C"}, $GNG{$g}{"P"}, $thycol,
                           (exists($DVgns->{$g}{'FLG'}) && exists($DVgns->{$g}{'FLG'}[4])
                            ? $DVgns->{$g}{'FLG'}[4] : 0));
    };

    open(EXTJSN,  "> $xfile") || die("### ERROR ### Cannot open web json(lvl:$numlvl) file: $xfile\n");
    print EXTJSN "\{\n",&json_header_ext($numlvl + 1),$jstr,"\n\}\n";
    close(EXTJSN);
    undef %GNG;

    # print DOTFILE "digraph G {\n graph [ splines = true, overlap = false, dpi=\"72\" ];\n node [ style = filled ];\n";
    print DOTFILE "digraph G {\n".
        "\tgraph [splines=true,overlap=true,dpi=\"72\"];\n".
        "\t node [style=filled];\n".
        "\t edge [color=\"#000000\"];\n";
    print DOSFILE "digraph G {\n".
        "\tgraph [splines=true,overlap=true,dpi=\"72\"];\n".
        "\t node [style=filled];\n".
        "\t edge [color=\"#888888\"];\n";
    print XMLFILE &graphml_header();
    # print JSNFILE &json_header(); # comments are not allowed in the JSON file
    # unless a >>'__comment': "blabla"<< element of type string is included

    my @nodes = ();
    my @edges = ();
    my ($thylvl, $nxtlvl, $mylvl, $mychldflg, $thycol, $mycol);
    my %idcount = ( "NNODE" => 0, "NODES" => {}, "NEDGE" => 0, "EDGES" => {} );

    @thyids = keys %$subgraph;

    foreach my $idA (@thyids) {

        $thylvl = (exists($subgraph->{$idA}) && defined($subgraph->{$idA}{'LVL'})) ? $MAXLVLS + $subgraph->{$idA}{'LVL'} : undef;

        $thycol = (defined($thylvl)
                   ? $BGCOL[ $thylvl ]
                   : (exists($rids->{$idA}) ? $DVCOL : $NACOL));

        exists($idcount{"NODES"}{$idA}) || do {
            printf DOTFILE "\t\"%s\" [color=\"%s\"]; // A\n", $idA, $thycol;
            printf DOSFILE "\t\"%s\" [color=\"%s\"]; // A\n", $idA, $thycol;
            $idcount{"NODES"}{$idA} = $idcount{"NNODE"}++;
            print  XMLFILE &graphml_node($idcount{"NODES"}{$idA}, $idA, $thycol,
                                         (exists($adesc->{$idA}) ? $adesc->{$idA} : undef),
                                         $subgraph->{$idA}{'ALIASES'});
            push @nodes, &json_node($idcount{"NODES"}{$idA}, $idA, $thycol);
        };

        my @adjlst = keys %{ $subgraph->{$idA}{'ADJLST'} };

        foreach my $idB (@adjlst) {

            $mylvl = (exists($subgraph->{$idB}) && defined($subgraph->{$idB}{'LVL'})) ? $MAXLVLS + $subgraph->{$idB}{'LVL'} : undef;

            $mycol = (defined($mylvl)
                      ? $BGCOL[ $mylvl ]
                      : (exists($rids->{$idB}) ? $DVCOL : $NACOL));

            exists($idcount{"NODES"}{$idB}) || do {
                printf DOTFILE "\t\"%s\" [color=\"%s\"]; // B\n", $idB, $mycol;
                printf DOSFILE "\t\"%s\" [color=\"%s\"]; // B\n", $idB, $mycol;
                $idcount{"NODES"}{$idB} = $idcount{"NNODE"}++;
                print  XMLFILE &graphml_node($idcount{"NODES"}{$idB}, $idB, $mycol,
                                             (exists($adesc->{$idB}) ? $adesc->{$idB} : undef),
                                             $subgraph->{$idB}{'ALIASES'});
                push @nodes, &json_node($idcount{"NODES"}{$idB}, $idB, $mycol);
            };

            exists($idcount{"EDGES"}{$idA.$idB}) || do {
                my ($weight, @wgs, $iary);
                $iary = (exists($subgraph->{$idA}{'ADJLST'}{$idB}) && exists($subgraph->{$idA}{'ADJLST'}{$idB}{'T'}))
                        ? $subgraph->{$idA}{'ADJLST'}{$idB}
                        : { 'P' => [ 0 ], 'G' => [ 0 ], 'U' => [ 0 ], 'T' => 0 };
                ($weight, @wgs) = ($iary->{'T'}, $iary->{'P'}[0], $iary->{'G'}[0], $iary->{'U'}[0]);
                                  # ($weight, @wgs) = &count_interactions_by_type($subgraph, $idA, $idB, \%iary);
                # my $weight = exists($subgraph->{$idA}{'ADJLST'}{$idB}) ? scalar(keys %{ $subgraph->{$idA}{'ADJLST'}{$idB} }) : 1;
                printf DOTFILE "\t\"%s\"->\"%s\" [arrowhead=normal,weight=%s,penwidth=%s,color=\"%s\",iphy=%d,igen=%d,iunk=%d];\n",
                               $idA, $idB, $weight, $weight+1, $LNCOL[0], @wgs;
                for (my $wi = 0; $wi < 3; $wi++) {
                    my $w = $wgs[$wi];
                    next unless $w > 0;
                    printf DOSFILE "\t\"%s\"->\"%s\" [arrowhead=normal,weight=%s,penwidth=%s,color=\"%s\"];\n",
                                   $idA, $idB, $w, $w, $EDGECOL[$wi];
                };    
                $idcount{"EDGES"}{$idA.$idB} = $idcount{"NEDGE"}++;
                print  XMLFILE &graphml_edge($idcount{"EDGES"}{$idA.$idB},
                                             $idcount{"NODES"}{$idA},
                                             $idcount{"NODES"}{$idB},
                                             $LNCOL[0], $weight, $iary);
                push @edges, &json_edge($idcount{"EDGES"}{$idA.$idB},
                                        $idcount{"NODES"}{$idA},
                                        $idcount{"NODES"}{$idB},
                                        $LNCOL[0], $weight, $iary, $idA, $idB);
            };

        }; # foreach $idB

    }; # foreach $idA

    @$ids = @thyids; # %uqids;

    print DOTFILE "}\n";
    print DOSFILE "}\n";
    print XMLFILE &graphml_trailer();
    print JSNFILE &json_trailer(\@nodes, \@edges);

    close(DOTFILE);
    close(DOSFILE);
    close(XMLFILE);
    close(JSNFILE);

    undef %idcount;

    # Running DOT command over graph file
    (my $svgfile = $ofile) =~ s/\.dot$/.svg/o;
    my $cmd = "neato -Tsvg $ofile > $svgfile 2> $svgfile.log"; # neato with overlap=false, twopi does not look so well...
    printf STDERR "### LEVEL %s: CREATING GRAPH with COMMAND:\n### %s\n", $numlvl, $cmd if $_verbose{'RAW'};
    abs($numlvl) < 2 && do {
        system($cmd) if $DRAWflg;
        # print STDERR Data::Dumper->Dump([ \%GNG ], [ qw/ *GNG / ]),"\n" if $_verbose{'RAW'};
    };

} # build_graph

sub getrbgint($) { # get hex value, return three integers between 0/255
    my $h = shift;
    return ( map { hex("0x".$_) } ($h =~ /([^\#]{2})([^\#]{2})([^\#]{2})/) )
} # getrbgint

sub save_full_graph($$$$) { # now must run this step as it simplifies evidence lists (PGU)
    my ($fileprefix, $graph, $rids, $adesc) = @_;

    my $ofile = $fileprefix."_wholegraph.dot";
    my $Ofile = $fileprefix."_wholegraph_split.dot";
    my $gfile = $fileprefix."_wholegraph.graphml";
    my $jfile = $fileprefix."_wholegraph.json";

    printf STDERR "### WRITING WHOLE GRAPH DATA into: %s ...", $ofile if $_verbose{'RAW'};
    open(DOTFILE, "> $ofile") || die("### ERROR ### Cannot open whole-graph dot file: $ofile\n");
    open(DOSFILE, "> $Ofile") || die("### ERROR ### Cannot open whole-graph dot split file: $Ofile\n");
    open(XMLFILE, "> $gfile") || die("### ERROR ### Cannot open whole-graph graphml file: $gfile\n");
    open(JSNFILE, "> $jfile") || die("### ERROR ### Cannot open json(whole-graph) file: $jfile\n");

    print DOTFILE "digraph G {\n".
        "\tgraph [splines=true,overlap=true,dpi=\"72\"];\n".
        "\t node [style=filled];\n".
        "\t edge [color=\"#000000\"];\n";
    print DOSFILE "digraph G {\n".
        "\tgraph [splines=true,overlap=true,dpi=\"72\"];\n".
        "\t node [style=filled];\n".
        "\t edge [color=\"#888888\"];\n";
    print XMLFILE &graphml_header();

    my ($thylvl, $nxtlvl, $mylvl, $mychldflg, $thycol, $mycol);
    my %idcount = ( "NNODE" => 0, "NODES" => {}, "NEDGE" => 0, "EDGES" => {});

    my @thyids = keys %$graph;

    my @nodes = ();
    my @edges = ();
    my $dvcol = '#bb2d2b'; # $DVCOL
    foreach my $idA (@thyids) {

        $thycol = exists($rids->{$idA}) ? $dvcol : $NACOL;

        exists($idcount{"NODES"}{$idA}) || do {
            printf DOTFILE "\t\"%s\" [color=\"%s\"]; // A\n", $idA, $thycol;
            printf DOSFILE "\t\"%s\" [color=\"%s\"]; // A\n", $idA, $thycol;
            $idcount{"NODES"}{$idA} = $idcount{"NNODE"}++;
            print  XMLFILE &graphml_node($idcount{"NODES"}{$idA}, $idA, $thycol,
                                         (exists($adesc->{$idA}) ? $adesc->{$idA} : undef),
                                         $graph->{$idA}{'ALIASES'});
            push @nodes, &json_node($idcount{"NODES"}{$idA}, $idA, $thycol);
        };

        my @adjlst = keys %{ $graph->{$idA}{'ADJLST'} };

        foreach my $idB (@adjlst) {

            $mycol = exists($rids->{$idB}) ? $dvcol : $NACOL;

            exists($idcount{"NODES"}{$idB}) || do {
                printf DOTFILE "\t\"%s\" [color=\"%s\"]; // B\n", $idB, $mycol;
                printf DOSFILE "\t\"%s\" [color=\"%s\"]; // B\n", $idB, $mycol;
                $idcount{"NODES"}{$idB} = $idcount{"NNODE"}++;
                print  XMLFILE &graphml_node($idcount{"NODES"}{$idB}, $idB, $thycol,
                                             (exists($adesc->{$idB}) ? $adesc->{$idB} : undef),
                                             $graph->{$idB}{'ALIASES'});
                push @nodes, &json_node($idcount{"NODES"}{$idB}, $idB, $thycol);
            };

            exists($idcount{"EDGES"}{$idA.$idB}) || do {
                my ($weight, @wgs);
                ($weight, @wgs) = &count_interactions_by_type($graph, $idA, $idB);
                # my $weight = exists($graph->{$idA}{'ADJLST'}{$idB}) ? scalar(keys %{ $graph->{$idA}{'ADJLST'}{$idB} }) : 1;
                printf DOTFILE "\t\"%s\"->\"%s\" [arrowhead=normal,weight=%s,penwidth=%s,color=\"%s\",iphy=%d,igen=%d,iunk=%d];\n",
                               $idA, $idB, $weight, $weight+1, $DFCOL, @wgs;
                for (my $wi = 0; $wi < 3; $wi++) {
                    my $w = $wgs[$wi];
                    next unless $w > 0;
                    printf DOSFILE "\t\"%s\"->\"%s\" [arrowhead=normal,weight=%s,penwidth=%s,color=\"%s\"];\n",
                                   $idA, $idB, $w, $w, $EDGECOL[$wi];
                };    
                $idcount{"EDGES"}{$idA.$idB} = $idcount{"NEDGE"}++;
                print  XMLFILE &graphml_edge($idcount{"EDGES"}{$idA.$idB},
                                             $idcount{"NODES"}{$idA},
                                             $idcount{"NODES"}{$idB},
                                             $LNCOL[0], $weight, $graph->{$idA}{'ADJLST'}{$idB}); # \%iary);
                push @edges, &json_edge($idcount{"EDGES"}{$idA.$idB},
                                        $idcount{"NODES"}{$idA},
                                        $idcount{"NODES"}{$idB},
                                        $LNCOL[0], $weight, $graph->{$idA}{'ADJLST'}{$idB}, $idA, $idB); # \%iary);
            };

        }; # foreach $idB

    }; # foreach $idA

    print DOTFILE "}\n";
    print DOSFILE "}\n";
    print XMLFILE &graphml_trailer();
    print JSNFILE &json_trailer(\@nodes, \@edges);
    
    close(DOTFILE);
    close(DOSFILE);
    close(XMLFILE);
    close(JSNFILE);
    
    undef %idcount;

    print STDERR "...DONE\n" if $_verbose{'RAW'};

    print STDERR "### Evidence arrays simplified...\n",
                 Data::Dumper->Dump([ $graph ], [ qw( *GRAPH ) ]),"\n" if $_verbose{'DEBUG'};

} # save_full_graph $outprefix, \%GRAPH, \%DVgenes);

##
## GRAPHML output
sub graphml_header() {
    return <<'EOF';
<?xml version="1.0" encoding="UTF-8"?>
<graphml xmlns="http://graphml.graphdrawing.org/xmlns"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://graphml.graphdrawing.org/xmlns
     http://graphml.graphdrawing.org/xmlns/1.0/graphml.xsd">
 <key attr.name="Node Label"  attr.type="string" for="node" id="label"/>
 <key attr.name="Node Size"   attr.type="float"  for="node" id="size"/>
 <key attr.name="Node Class"  attr.type="string" for="node" id="class"/>
 <key attr.name="Node Data"   attr.type="string" for="node" id="ndata"/>
 <key attr.name="r"           attr.type="int"    for="node" id="r"/>
 <key attr.name="g"           attr.type="int"    for="node" id="g"/>
 <key attr.name="b"           attr.type="int"    for="node" id="b"/>
 <key attr.name="Edge Label"  attr.type="string" for="edge" id="nlabel"/>
 <key attr.name="Edge Weight" attr.type="float"  for="edge" id="weight"/>
 <key attr.name="Edge Class"  attr.type="string" for="edge" id="eclass"/>
 <key attr.name="Edge Data"   attr.type="string" for="edge" id="edata"/>
 <key attr.name="r"           attr.type="int"    for="edge" id="r"/>
 <key attr.name="g"           attr.type="int"    for="edge" id="g"/>
 <key attr.name="b"           attr.type="int"    for="edge" id="b"/>
 <key attr.name="Node Info"   attr.type="string" for="data" id="nodeinfo"/>
 <key attr.name="Edge Info"   attr.type="string" for="data" id="edgeinfo"/>
 <graph id="G" edgedefault="directed">
EOF
} # graphml_header

sub graphml_node(@) {
    my @par = @_;
    my @IA = qw/ ISHUGO HG AC EN SP OT /;
    scalar(@par) > 2 && do {
        my @rgb = &getrbgint($par[2]);
        my $dt = (exists($par[3]) && defined($par[3]))
            ? join("", map { sprintf("       <nodeinfo key=\"%s\">%s</nodeinfo>\n",
                                     $_, exists($par[3]->{$_}) ? $par[3]->{$_} : "NA")
                   } @IA )
            : "NA";
        $dt .= (exists($par[4]) && defined($par[4]))
            ? sprintf("       <nodeinfo key=\"aliases\"> %s </nodeinfo>\n", join(", ", @{ $par[4] }))
            : '';
        return sprintf("  <node id=\"%s\">\n".
                       "   <data key=\"label\">%s</data>\n".
                       "   <data key=\"r\">%d</data>\n".
                       "   <data key=\"g\">%d</data>\n".
                       "   <data key=\"b\">%d</data>\n".
                       "   <data key=\"ndata\">\n%s   </data>\n".
                       "  </node>\n",
                       $par[0], $par[1], @rgb, $dt);
        # $idcount{"NODES"}{$idA}, $idA, $RGBhex ...
    };
    return sprintf("  <node id=\"%s\" label=\"%s\"/>\n",
                   @par); # $idcount{"NODES"}{$idA}, $idA
} # graphml_node

sub graphml_edge(@) {
    my %Ikeys = qw( P physical G genetic U unknown );
    my @par = @_;
    scalar(@par) > 3 && do {
        my @rgb = &getrbgint($par[3]);
        my $wg = exists($par[4]) ? $par[4] : 0;
        my $dt = "NA";
        exists($par[5]) && do {
            my ($r, $T, $count, @refs, $cm, $einfo);
            $r = $par[5];
            $dt = '';
            foreach $T (qw/ P G U /) {
                ($count, @refs) = @{ $r->{$T} };
                $einfo = $count > 0
                    ? join('',
                           map {
                               my $g = $_;
                               $g =~ s/[\<\>]/:/og;
                               sprintf("        <edgeref>%s</edgeref>\n", $g)
                           } @refs )
                    : '';
                $dt .= sprintf("       <edgeinfo key=\"%s\">\n".
                               "        <edgecount>%s</edgecount>\n%s".
                               "       </edgeinfo>\n", $Ikeys{$T}, $count, $einfo);
            };
        };
        return sprintf("  <edge id=\"e%d\" directed=\"true\" source=\"%s\" target=\"%s\">\n".
                       "   <data key=\"r\">%d</data>\n".
                       "   <data key=\"g\">%d</data>\n".
                       "   <data key=\"b\">%d</data>\n".
                       "   <data key=\"weight\">%.3f</data>\n".
                       "   <data key=\"edata\">\n%s   </data>\n".
                       "  </edge>\n",
                       $par[0], $par[1], $par[2], @rgb, exists($par[4]) ? $par[4] : 1, $dt);
        # $idcount{"EDGES"}{$idA.$idB}, $idcount{"NODES"}{$idA}, $idcount{"NODES"}{$idB}, $RGBhex ...
    };
    return sprintf("  <edge id=\"e%d\" directed=\"true\" source=\"%s\" target=\"%s\"/>\n",
                   @par);
} # graphml_edge

sub graphml_trailer() {
    return <<'EOF';
 </graph>
</graphml>
EOF
} # graphml_trailer

##
## JSON output format
sub json_header_ext($) {
    my $level = shift;
    return '  "OPTIONS": { "maxlevel": '.$level.' },'."\n";
} # json_header_ext

sub json_node_ext($$$$$) {
    my ($id,$crf,$prf,$col,$flg) = @_;
    my @C = keys %$crf;
    my @P = keys %$prf;
    $flg = 0 unless defined($flg);
    return '  "'.$id.'": {'."\n".
        '      "child":  [ '.(scalar(@C) > 0 ? join(", ", map { "\"$_\"" } @C) : q{}).' ],'."\n".
        '      "parent": [ '.(scalar(@P) > 0 ? join(", ", map { "\"$_\"" } @P) : q{}).' ],'."\n".
        '      "color": "'.$col.'",'."\n".
        '      "synd": "'.$flg.'" }';
} # json_node_ext

#-------------> Cytoscape format
# {
#    "nodes" : [
#       {
#          "cluster" : "c_0",
#          "type" : "Y",
#          "category" : "blue",
#          "id" : "n_0",
#          "description" : "Assumenda atque nostrum veniam quia sunt.",
#          "size" : 71.9857610890433
#       },
#       ...
#    ],
#    "edges" : [
#       {
#          "rate" : 24.1752238846782,
#          "cluster" : "c_0",
#          "to" : "n_9",
#          "from" : "n_0",
#          "probability" : 0.254679689733507,
#          "id" : "e_0"
#       },
#       ...
#    ]
# }
# Nevertheless, we must tweak a little bit the format to adapt to the library.
# With the help of underscore.js, we can transform the loaded graph:
#        var cyGraph = {
#           elements: {
#             nodes: _.map(graph.nodes, function (n) {
#                 return {data: n};
#             }),
#             edges: _.map(graph.edges, function (e) {
#                 return {data: {source: e.from, target: e.to, rate: e.rate}};
#             })
#           } // elements
#         };
sub json_header() {
    return <<'EOF';
//
//  JSON edges and nodes for a directed graph
//
//  Import with:
//
//      cy.add( JSON.parse( jsonString ) )
//
EOF
} # json_header

sub json_node(@) {
    my @par = @_;
    scalar(@par) > 2 && do {
        # my @rgb = &getrbgint($par[2]);
        # my $dt = exists($par[3])
        #     ? scalar(@{ $par[3] })
        #     : "";
        return sprintf("  { \"data\": {\n".
                       "      \"id\" : \"%s\",\n".
                       "      \"name\" : \"%s\",\n".
                       "      \"background-color\" : \"%s\",\n".
                       "      \"weight\" : %s\n".
                       "    } }",
                       $par[0], $par[1], $par[2], exists($par[3]) ? scalar($par[3]) : 1);
        # $idcount{"NODES"}{$idA}, $idA, $RGBhex ...
    };
    return sprintf("  { \"data\": {\n".
                   "      \"id\" : \"%s\",\n".
                   "      \"name\" : \"%s\"\n".
                   "    } }",
                   @par);
    # $idcount{"NODES"}{$idA}, $idA
} # json_node

sub json_edge(@) {
    my @par = @_;
    scalar(@par) > 3 && do {
        # my @rgb = &getrbgint($par[3]);
        # my $dt = exists($par[5])
        #     ? scalar(@{ $par[5] })
        #     : "";
        my $wg = exists($par[4]) ? $par[4] : 0;
        my $str = "\n";
        my ($ga, $gb) = ($par[1], $par[2]);
        scalar(@par) > 5 && do {
            my $r = $par[5];
            $str = sprintf(",\n      \"evidences\" : {\n".
                           "        \"physical\" : %s,\n".
                           "         \"genetic\" : %s,\n".
                           "         \"unknown\" : %s\n".
                           "      }\n",
                           map {
                               my ($count, @refs, $cm);
                               ($count, @refs) = @{ $r->{$_} };
                               $cm = scalar(@refs) > 0 ? ',' : '';
                               sprintf("[ %d%s %s ]",
                                       $count, $cm,
                                       join(", ",
                                            map {
                                                my $s = $_;
                                                $s =~ s/[\"\'`´]/\'/og;
                                                '"'.$s.'"'
                                            } @refs))
                           } qw/ P G U / );
        };
        scalar(@par) > 6 && do {
            ($ga, $gb) = ($par[6], $par[7]);
        };
        return sprintf("  { \"data\": {\n".
                       "      \"id\" : \"e%s\",\n".
                       "      \"source\" : \"%s\",\n".
                       "      \"srclbl\" : \"%s\",\n".
                       "      \"target\" : \"%s\",\n".
                       "      \"tgtlbl\" : \"%s\",\n".
                       "      \"background-color\" : \"%s\",\n".
                       "      \"strength\" : %s%s".
                       "    } }",
                       $par[0], $par[1], $ga, $par[2], $gb, $par[3], $wg, $str);
        # $idcount{"EDGES"}{$idA.$idB}, $idcount{"NODES"}{$idA}, $idcount{"NODES"}{$idB}, $RGBhex ...
    };
    return sprintf("  { \"data\": {\n".
                   "      \"id\" : \"e%s\",\n".
                   "      \"source\" : \"%s\",\n".
                   "      \"target\" : \"%s\"\n".
                   "    } }",
                   @par);

} # json_edge

sub json_trailer($$) {
    my ($nodes, $edges) = @_;
    my ($nodes_str, $edges_str) = (q{}, q{});
    $nodes_str = join(",\n", @$nodes) if scalar(@$nodes) > 0;
    $edges_str = join(",\n", @$edges) if scalar(@$edges) > 0;
    return <<"EOF";
{
  "nodes" : [
$nodes_str
  ],
  "edges" : [
$edges_str
  ]
}
EOF
} # json_trailer

##

## Function taken from global.pm, but now the module is being used
# sub timing($) {
#     my $ary = shift;
#     my $mx = $#{$ary};
#     return timestr( timediff($ary->[$mx], $ary->[($mx - 1)]) );
# } # sub timing

sub compute_shortests_paths($$$$$$$) { # using Graph::Directed
    my ($fileprefix, $R, $DVids, $ids, $sdi, $adesc, $DVgns, $graph, $apsp, @vertices, $path_len,
        %GNG, %SKEL, @IDS, @DVs, %fnd, @NWIDS, $L, $l, $lids, @T, $STR, $cmd, $gfile, @nodes, @edges);

    ($fileprefix, $R, $DVids, $ids, $sdi, $adesc, $DVgns) = @_;

    print STDERR "### COMPUTING GRAPH SHORTEST PATHs\n" if $_verbose{'RAW'};

    my ($thycol, $defcol, $newcol, $edgecol) = ('#CBB0F0', '#F1A111', '#CCCCCC', '#000000'); # purple-lvl0 / orange / lightgrey
    my $ofile = $fileprefix."_graph_allpaths.dot";
    my $oXfile = $fileprefix."_graph_allpaths.graphml";
    my $dfile = $fileprefix."_graph_skeleton.dot";
    my $Dfile = $fileprefix."_graph_skeleton_split.dot";
    my $dXfile = $fileprefix."_graph_skeleton.graphml";
    my $dJfile = $fileprefix."_graph_skeleton.json"; # level 0
    # EXTJSN fileprefix_graph_web_skeleton.json is computed at the end

    open(DOTFILE, "> $ofile") || die("### ERROR ### Cannot open dot(allpaths) file: $ofile\n");
    open(SKLFILE, "> $dfile") || die("### ERROR ### Cannot open dot(skeleton) file: $dfile\n");
    open(SKSFILE, "> $Dfile") || die("### ERROR ### Cannot open dot(skeleton) split file: $Dfile\n");
    open(DOXFILE, "> $oXfile") || die("### ERROR ### Cannot open graphml(allpaths) file: $oXfile\n");
    open(SKXFILE, "> $dXfile") || die("### ERROR ### Cannot open graphml(skeleton) file: $dXfile\n");
    open(JSNFILE, "> $dJfile") || die("### ERROR ### Cannot open json(skeleton) file: $dJfile\n");

    $STR = "digraph G {\n".
        "\tgraph [splines=true,overlap=false,dpi=\"72\"];\n".
        "\t node [style=filled,color=\"$defcol\"];\n".
        "\t edge [color=\"#888888\"];\n";
    print DOTFILE $STR;
    print SKLFILE $STR;
    print SKSFILE $STR;
    print DOXFILE &graphml_header();
    print SKXFILE &graphml_header();
    my %idcount = ( "FULL" => { "NNODE" => 0, "NODES" => {}, "NEDGE" => 0, "EDGES" => {} },
                    "SKEL" => { "NNODE" => 0, "NODES" => {}, "NEDGE" => 0, "EDGES" => {} });

    # Initialize graph
    %SKEL = ();
    $graph = Graph::Directed->new; # new Boost::Graph();
    @IDS = keys %{ $R };
    $lids = scalar @IDS;
    @NWIDS = keys %{$DVids};
    @nodes = ();
    @edges = ();

    print STDERR "##--> Initializing Paths GRAPH [nodes = $lids]...\n" if $_verbose{'RAW'};

    foreach my $A (@IDS) {
        foreach my $B (keys %{ $R->{$A}{'ADJLST'} }) {
            $graph->add_edge($A, $B);
            # $graph->add_weighted_edge($A, $B, scalar(keys %{ $R->{$A}{'ADJLST'}{$B} }));
        };
    };

    # Getting the DV genes nodes
    print STDERR "##--> Initializing NODES Selection... " if $_verbose{'RAW'};
    @DVs = ();
    %fnd = ();
    %GNG = (); # gene sub-graph
    foreach my $r (@NWIDS) {
        exists($fnd{$r}) || do {
            $fnd{$r} = 0;
            push @DVs, $r;
            &init_adjlist(\%SKEL, $r); # ensuring to have at least all the DVgenes on the output graphs
        };
        $fnd{$r}++;
    };
    $L = $#DVs;
    $l = $L + 1;
    print STDERR $l, " nodes, running ", ($L * $l), " searches\n" if $_verbose{'RAW'};

    #APSP# # Getting the shortests paths in a matrix-wise way for all pairs,
    #APSP# # ...maybe skip those already found in a path...
    #APSP# print STDERR "##--> Building object for AllPairsShortestPaths Floyd-Warshall...\n" if $_verbose{'RAW'};
    #APSP# @T = (new Benchmark);
    #APSP# $apsp = $graph->APSP_Floyd_Warshall;
    #APSP# push @T, (new Benchmark);
    #APSP# print STDERR "##--> APSP object created in ",&timing(\@T),"\n" if $_verbose{'RAW'};
    #
    print STDERR "##--> Looking for PATHS...\n" if $_verbose{'RAW'};
    %fnd = (); @T = ();
    my $c = 0;
    @T = (new Benchmark);
    #
    # AS IT IS A DIRECTED GRAPH,
    # WE MUST CONSIDER SHORTEST PATHS IN BOTH DIRECTIONS
    # THUS THE LOOPS DEFINITION BELOW WILL MISS INTERACTIONS !!!
    #   for (my $i = 0; $i < $L; $i++) {
    #     for (my $j = $i + 1; $j < $l; $j++) {
    #
    my %edgecount = ();
    for (my $i = 0; $i < $l; $i++) {
        for (my $j = 0; $j < $l; $j++) {
            $i == $j && next;
            #
            my ($A, $B) = ($DVs[$i], $DVs[$j]);
            exists($GNG{$A}) || ($GNG{$A} = {});
            exists($GNG{$B}) || ($GNG{$B} = {});
            printf STDERR ":%05d: ----> %s [%d] x %s [%d]", ++$c, $A, $i, $B, $j if $_verbose{'RAW'};
            #APSP# @vertices = $apsp->path_vertices($A, $B);
            #APSP# $path_len = $apsp->path_length($A, $B);
            @vertices = $graph->SP_Dijkstra($A, $B);
            $path_len = scalar(@vertices);
            # print STDERR Data::Dumper->Dump([ $paths ],[ qw/ *paths / ]) if $_verbose{'RAW'};
            ($path_len == 0) && do {
                print STDERR " ... NO PATH FOUND\n" if $_verbose{'RAW'};
                next;
            };
            print STDERR " ... GOT A PATH with $path_len NODES\n" if $_verbose{'RAW'}; # in ",&timing(\@T),"\n";
            foreach my $g (@vertices) {
                exists($fnd{$g}) || do {
                    my $mycol = exists($DVids->{$g}) ? $thycol : $newcol;
                    $STR = sprintf("\t\"%s\" [color=\"%s\"];\n", $g, $mycol);
                    print DOTFILE $STR;
                    print SKLFILE $STR;
                    print SKSFILE $STR;
                    $idcount{"FULL"}{"NODES"}{$g} = $idcount{"FULL"}{"NNODE"}++;
                    print DOXFILE &graphml_node($idcount{"FULL"}{"NODES"}{$g}, $g, $mycol,
                                                (exists($adesc->{$g}) ? $adesc->{$g} : undef),
                                                $R->{$g}{'ALIASES'});
                    $idcount{"SKEL"}{"NODES"}{$g} = $idcount{"SKEL"}{"NNODE"}++;
                    print SKXFILE &graphml_node($idcount{"SKEL"}{"NODES"}{$g}, $g, $mycol,
                                                (exists($adesc->{$g}) ? $adesc->{$g} : undef),
                                                $R->{$g}{'ALIASES'});
                    push @nodes, &json_node($idcount{"SKEL"}{"NODES"}{$g}, $g, $mycol);
                    $fnd{$g}=0;
                };
                $fnd{$g}++;
            };
            print DOTFILE "\t", join("->", map { '"'.$_.'"' } @vertices), ";\n";
            for (my $z = 1; $z < scalar(@vertices); $z++) {
                my ($za,$zb) = ($vertices[$z-1], $vertices[$z]);
                exists($fnd{$za.$zb}) || do {
                    $idcount{"FULL"}{"EDGES"}{$za.$zb} = $idcount{"FULL"}{"NEDGE"}++;
                    $idcount{"SKEL"}{"EDGES"}{$za.$zb} = $idcount{"SKEL"}{"NEDGE"}++;
                    $edgecount{$za}{$zb}++;
                    $fnd{$za.$zb} = 0;
                };
            };
            
            print STDERR "Shortest Path:" .
                join("->", @vertices) .
                " Cost:" . $path_len . "\n" if $_verbose{'RAW'};
            
            for (my ($i, $j) = (0, 1); $j < scalar(@vertices); $i++, $j++) {
                my ($gidA,$gidB) = @vertices[ $i, $j ];
                &init_adjlist(\%SKEL, $gidA);
                &init_adjlist(\%SKEL, $gidB);
                exists($SKEL{$gidA}{'ADJLST'}{$gidB}) || ($SKEL{$gidA}{'ADJLST'}{$gidB} = 0);
                $SKEL{$gidA}{'ADJLST'}{$gidB}++;
                exists($GNG{$A}{$gidA}) || ($GNG{$A}{$gidA} = 0);
                exists($GNG{$A}{$gidB}) || ($GNG{$A}{$gidB} = 0);
                exists($GNG{$B}{$gidA}) || ($GNG{$B}{$gidA} = 0);
                exists($GNG{$B}{$gidB}) || ($GNG{$B}{$gidB} = 0);
                $GNG{$A}{$gidA}++;
                $GNG{$A}{$gidB}++;
                $GNG{$B}{$gidA}++;
                $GNG{$B}{$gidB}++;
            };
        };
    };
    #
    my $edgeCol = $edgecol;
    foreach my $za (keys %edgecount) {
        foreach my $zb (keys %{ $edgecount{$za} }) { 
            my ($wg, @wgs, $iary);
            $iary = (exists($R->{$za}{'ADJLST'}{$zb}) && exists($R->{$za}{'ADJLST'}{$zb}{'T'}))
                    ? $R->{$za}{'ADJLST'}{$zb}
                    : { 'P' => [ 0 ], 'G' => [ 0 ], 'U' => [ 0 ], 'T' => 0 };
            ($wg, @wgs) = ($iary->{'T'}, $iary->{'P'}[0], $iary->{'G'}[0], $iary->{'U'}[0]);
                          # ($wg, @wgs) = &count_interactions_by_type($R, $za, $zb, \%iary);
            # print DOTFILE "\t\"$za\"->\"$zb\" [weight=$wg,penwidth=$wg];\n";
                           # "\t\"$za\"->\"$zb\" [weight=$wg,penwidth=".$wg+1.",iphy=$wgs[0],igen=$wgs[1],iunk=$wgs[2]];\n";
            printf SKLFILE "\t\"%s\"->\"%s\" [weight=%s,penwidth=%s,iphy=%d,igen=%d,iunk=%d];\n",
                           $za, $zb, $wg, $wg+1, @wgs;
            for (my $wi = 0; $wi < 3; $wi++) {
                my $w = $wgs[$wi];
                next unless $w > 0;
                printf SKSFILE "\t\"%s\"->\"%s\" [weight=%s,penwidth=%s,color=\"%s\"];\n",
                               $za, $zb, $w, $w, $EDGECOL[$wi];
            };
            print  DOXFILE &graphml_edge($idcount{"FULL"}{"EDGES"}{$za.$zb},
                                         $idcount{"FULL"}{"NODES"}{$za},
                                         $idcount{"FULL"}{"NODES"}{$zb},
                                         $edgeCol, $wg, $iary);
            print  SKXFILE &graphml_edge($idcount{"SKEL"}{"EDGES"}{$za.$zb},
                                         $idcount{"SKEL"}{"NODES"}{$za},
                                         $idcount{"SKEL"}{"NODES"}{$zb},
                                         $edgeCol, $wg, $iary);
            push @edges, &json_edge($idcount{"SKEL"}{"EDGES"}{$za.$zb},
                                    $idcount{"SKEL"}{"NODES"}{$za},
                                    $idcount{"SKEL"}{"NODES"}{$zb},
                                    $edgeCol, $wg, $iary, $za, $zb);
        };
    };
    
    push @T, (new Benchmark);
    print STDERR "##--> Looking for PATHS took ",&timing(\@T),"\n" if $_verbose{'RAW'};

    print STDERR "##--> Saving DOT/SKEL...\n" if $_verbose{'RAW'};

    # Setting "not found" color for those DVgenes not connected
    foreach my $id (@NWIDS) {
        (exists($fnd{$id})) || do {
            $STR = sprintf("\t\"%s\" [color=\"%s\"];\n", $id, $defcol);
            print DOTFILE $STR;
            print SKLFILE $STR;
            print SKSFILE $STR;
            $idcount{"FULL"}{"NODES"}{$id} = $idcount{"FULL"}{"NNODE"}++;
            print DOXFILE &graphml_node($idcount{"FULL"}{"NODES"}{$id}, $id,
                                        $defcol,
                                        (exists($adesc->{$id}) ? $adesc->{$id} : undef),
                                        $R->{$id}{'ALIASES'});
            $idcount{"SKEL"}{"NODES"}{$id} = $idcount{"SKEL"}{"NNODE"}++;
            print SKXFILE &graphml_node($idcount{"SKEL"}{"NODES"}{$id}, $id,
                                        $defcol,
                                        (exists($adesc->{$id}) ? $adesc->{$id} : undef),
                                        $R->{$id}{'ALIASES'});
            push @nodes, &json_node($idcount{"SKEL"}{"NODES"}{$id}, $id, $defcol);
            $fnd{$id} = 0; # needed later
        };
    };
    
    print DOTFILE "}\n";
    print DOXFILE &graphml_trailer();
    print JSNFILE &json_trailer(\@nodes, \@edges);

    close(DOTFILE);
    close(DOXFILE);
    close(JSNFILE);

    # # Drawing skeleton edges -> already stored on $fnd{$za.$zb} bloc above
    # foreach my $gA (keys %SKEL) {
    # 	foreach my $gB (keys %{ $SKEL{$gA}{'ADJLST'} }) {
    # 	    print SKLFILE "\t \"$gA\"->\"$gB\";\n";
    # 	    exists($idcount{"SKEL"}{"EDGES"}{$gA.$gB})
    # 		|| ($idcount{"SKEL"}{"EDGES"}{$gA.$gB} = $idcount{"SKEL"}{"NEDGE"}++);
    # 	    print SKXFILE &graphml_edge($idcount{"SKEL"}{"EDGES"}{$gA.$gB},
    # 					$idcount{"SKEL"}{"NODES"}{$gA},
    # 					$idcount{"SKEL"}{"NODES"}{$gB},
    # 					$edgecol, 1);
    # 	};
    # };

    print SKLFILE "}\n";
    print SKSFILE "}\n";
    print SKXFILE &graphml_trailer();
    close(SKLFILE);
    close(SKSFILE);
    close(SKXFILE);

    undef %idcount;

    # compiling plots
    ($gfile = $ofile) =~ s/\.dot$/.svg/o;
    $cmd = "neato -Tsvg $ofile > $gfile 2> $gfile.log"; # neato with overlap=false, twopi does not look so well...
    printf STDERR "### LEVEL %s: CREATING GRAPH with COMMAND:\n### %s\n", "**ALLPATHS**", $cmd if $_verbose{'RAW'};
    system($cmd) if $DRAWflg;

    ($gfile = $dfile) =~ s/\.dot$/.svg/o;
    $cmd = "neato -Tsvg $dfile > $gfile 2> $gfile.log"; # neato with overlap=false, twopi does not look so well...
    printf STDERR "### LEVEL %s: CREATING GRAPH with COMMAND:\n### %s\n", "**SKEL**", $cmd if $_verbose{'RAW'};
    system($cmd) if $DRAWflg;

    # Saving gene subnetworks
    print STDERR "##--> Saving GENE sub-networks...\n" if $_verbose{'RAW'};
    my $jfile = $fileprefix."_genes_subnetwork.json";

    my $jstr = '';
    foreach my $k (@NWIDS) { # (keys %GNG) {

        $jstr .= ($jstr ne q{} ? ",\n" : '') .
            (exists($GNG{$k})
             ? " \"$k\": [ " . join(", ", map { "\"$_\"" } keys %{ $GNG{$k} }) . " ]"
             : " \"$k\": [ ]");

    };

    open(JFILE, "> $jfile") || die("### ERROR ### Cannot open gene subnetworks file (JSON): $jfile\n");
    print JFILE "\{\n$jstr\n\}\n";
    close(JFILE);

    # Saving  skeleton in JSON format for the web browser
    print STDERR "##--> Saving SKEL in JSON...\n" if $_verbose{'RAW'};
    my $xfile = $fileprefix."_graph_web_skeleton.json";

    $jstr = '';
    my %TGNG = ();

    foreach my $g (@NWIDS) {
        exists($SKEL{$g}) || ($SKEL{$g}{'ADJLST'} = {});
    };
    foreach my $gA (keys %SKEL) {
        exists($TGNG{$gA}) || ($TGNG{$gA} = { "C" => {}, "P" => {} });
        foreach my $gB (keys %{ $SKEL{$gA}{'ADJLST'} }) {
            exists($TGNG{$gB}) || ($TGNG{$gB} = { "C" => {}, "P" => {} });
            $TGNG{$gA}{"C"}{$gB}++;
            $TGNG{$gB}{"P"}{$gA}++;
        };
    };

    print STDERR Data::Dumper->Dump([ \%SKEL, \%TGNG ], [ qw( *SKEL *TGNG ) ]), "\n" if $_verbose{DEBUG};

    foreach my $g (keys %TGNG) {
        my ($cc,$pc) = (scalar(keys %{ $TGNG{$g}{"C"} }), scalar(keys %{ $TGNG{$g}{"P"} }));
        $jstr .= ($jstr ne q{} ? ",\n" : '') .
            # (exists($TGNG{$g})
            # ?
            &json_node_ext($g, $TGNG{$g}{"C"}, $TGNG{$g}{"P"},
                           (exists($DVids->{$g})
                            ? ($cc + $pc == 0 ? $defcol : $thycol)
                            : $newcol),
                           (exists($DVgns->{$g}{'FLG'}) && exists($DVgns->{$g}{'FLG'}[4])
                            ? $DVgns->{$g}{'FLG'}[4] : 0));
        # : &json_node_ext($g, {}, {}, $defcol), 0);
    };

    open(EXTJSN, "> $xfile") || die("### ERROR ### Cannot open gene subnetworks file (JSON): $xfile\n");
    print EXTJSN "\{\n",&json_header_ext(1),$jstr,"\n\}\n";
    close(EXTJSN);
    undef %TGNG; undef %GNG;

    # Extending base ID lists with novel connecting nodes
    # @IDS = keys %fnd;
    # foreach my $id (@IDS) {
    # 	exists($DVids->{$id}) || push @NWIDS, $id;
    # };
    @NWIDS = keys %fnd; # much simpler due to "not found" initialized to 0 above...

    # Fixing lists...
    @$ids = @$sdi = @NWIDS;
    print STDERR "##\n##--> NODES SELECTED from SHORTEST PATH: ", scalar(@NWIDS), " of ", $lids, "\n",
                 "##--> NODES SELECTED ", sprintf("%dc/%dp/%dt", &count_nodes(\%SKEL)),
                 " of ", sprintf("%dc/%dp/%dt", &count_nodes($R)),
                 " : EDGES SELECTED ", &count_edges(\%SKEL), " of ", &count_edges($R),"\n##\n"
                     if $_verbose{'RAW'};

} # compute_shortests_paths

sub count_nodes($) {
    my $G = shift;
    # my %U = ();
    my ($p, $c) = (0, 0);
    foreach my $g (keys %$G) {
        $G->{$g}{'CHILDnum'} = scalar( keys %{ $G->{$g}{'ADJLST'} } ); # update CHILDnum at the same time
        if ($G->{$g}{'CHILDnum'} > 0) {
            $p++;
        } else {
            $c++;
        };
        # exists($U{$g}) || ($U{$g} = ++$p);
        # foreach my $j (keys %{ $G->{$g}{'ADJLST'} }) {
        #     exists($U{$j}) || ($U{$j} = ++$c);
        # };
    };
    # undef %U;
    return $c, $p, $c + $p;
} # count_nodes

sub count_edges($) {
    my $G = shift;
    my $c = 0;
    foreach my $g (keys %$G) {
        $G->{$g}{'CHILDnum'} = scalar( keys %{ $G->{$g}{'ADJLST'} } ); # update CHILDnum at the same time
        $c += $G->{$g}{'CHILDnum'};
        # $c += scalar( keys %{ $G->{$g}{'ADJLST'} } );
    };
    return $c;
} # count_edges

sub unalias_graph_ids($$$$$) {
    my ($alias, $adesc, $graph, $hparg, $rpgns) = @_;
    my $DEBUG = $_verbose{'DEBUG'};

    print STDERR "### UNALIASING GRAPH GENE IDS...\n" if $_verbose{'RAW'};

    printf STDERR "#--> UNALIAS GRAPH (PRE):  %d Child  %d Parent  %d Total NODES  %d EDGES\n".
        "#--> UNALIAS HPARG (PRE):  %d Child  %d Parent  %d Total NODES  %d EDGES\n".
        "#--> UNALIAS DVgenes (PRE):  %d GENE IDs\n",
        &count_nodes($graph), &count_edges($graph),
        &count_nodes($hparg), &count_edges($hparg),
        scalar(keys %$rpgns)
        if $_verbose{'RAW'};
    print STDERR join(" :: ", (keys %$rpgns)), "\n" if $_verbose{'RAW'};

    my %saila = ();

    # reverse alias hash first
    print STDERR "#-> Reversing alias hash...\n" if $_verbose{'RAW'};
    foreach my $pid (keys %$alias) {
        $saila{$pid} = $pid;
        foreach my $sid (keys %{ $alias->{$pid} }) { ## removed because %unalias
            ## my $sid = $alias->{$pid};
    	    next if $pid eq $sid;
    	    # exists($alias->{$sid}) && do {
    	    (exists($adesc->{$sid}) || exists($alias->{$sid})) && do {
                # avoid cross referencing genes that may have an equivalent synonim ?
                # ISSUE: how to avoid different genes having the same synonim ?
                # CURRENT SOLUTION: remove putative misleading synonims... (see next line)
                # ensure it does not appears also on the alias table we produce
                ## delete($alias->{$pid}); ## {$sid});
                next;
    	    };
            ## exists($saila{$sid}) || ($saila{$sid} = {});
            ## exists($saila{$sid}{$pid}) || ($saila{$sid}{$pid} = 0);
            ## $saila{$sid}{$pid}++;
            $saila{$sid} = $pid;
    	};
    };

    # fixing childs ids
    my (@Tary, @tary);
    @Tary = keys %{ $graph };
    foreach my $pid (@tary) {
        @tary = keys %{ $graph->{$pid}{'ADJLST'} };
        foreach my $kid (@tary) {
            exists($saila{$kid}) && do {
                my $aid = $saila{$kid};
                $aid eq $kid && next;
                exists($graph->{$pid}{'ADJLST'}{$aid}) || do {
                    $graph->{$pid}{'ADJLST'}{$aid} = $graph->{$pid}{'ADJLST'}{$kid};
                    delete($graph->{$pid}{'ADJLST'}{$kid});
                    next;
                };
                # both keys already exists
                foreach my $lbl (keys %{ $graph->{$pid}{'ADJLST'}{$aid} }) {
                    if (exists($graph->{$pid}{'ADJLST'}{$kid}{$lbl})) {
                        $graph->{$pid}{'ADJLST'}{$aid}{$lbl}[0] += shift @{ $graph->{$pid}{'ADJLST'}{$kid}{$lbl} };
                        push @{ $graph->{$pid}{'ADJLST'}{$aid}{$lbl} }, @{ $graph->{$pid}{'ADJLST'}{$kid}{$lbl} };
                    } else {
                        $graph->{$pid}{'ADJLST'}{$aid}{$lbl} = $graph->{$pid}{'ADJLST'}{$kid}{$lbl};
                    };
                    delete($graph->{$pid}{'ADJLST'}{$kid}{$lbl});
                };
                delete($graph->{$pid}{'ADJLST'}{$kid});
            };
        };
    };
    # # fixing childs ids for inverse graph
    # foreach my $pid (keys %{ $hparg }) {
    #     foreach my $kid (keys %{ $hparg->{$pid}{'ADJLST'} }) {
    #         exists($saila{$kid}) && do {
    #             my $aid = $saila{$kid};
    #             $aid eq $kid && next;
    #             exists($hparg->{$pid}{'ADJLST'}{$aid}) || do {
    #                 $hparg->{$pid}{'ADJLST'}{$aid} = $hparg->{$pid}{'ADJLST'}{$kid};
    #                 delete($hparg->{$pid}{'ADJLST'}{$kid});
    #                 next;
    #             };
    #             # both keys already exists
    #             foreach my $lbl (keys %{ $hparg->{$pid}{'ADJLST'}{$aid} }) {
    #                 if (exists($hparg->{$pid}{'ADJLST'}{$kid}{$lbl})) {
    #                     $hparg->{$pid}{'ADJLST'}{$aid}{$lbl}[0] += shift @{ $hparg->{$pid}{'ADJLST'}{$kid}{$lbl} };
    #                     push @{ $hparg->{$pid}{'ADJLST'}{$aid}{$lbl} }, @{ $hparg->{$pid}{'ADJLST'}{$kid}{$lbl} };
    #                 } else {
    #                     $hparg->{$pid}{'ADJLST'}{$aid}{$lbl} = $hparg->{$pid}{'ADJLST'}{$kid}{$lbl};
    #                 };
    #                 delete($hparg->{$pid}{'ADJLST'}{$kid}{$lbl});
    #             };
    #             delete($hparg->{$pid}{'ADJLST'}{$kid});
    #         };
    #     };
    # };

    # now fix any aliased parents ids on the graph hashes
    print STDERR "#-> Unaliasing graph keys...\n" if $_verbose{'RAW'};
    foreach my $pid (keys %saila) {
        ## foreach my $pid (keys %$alias) {
        ## foreach my $sid (keys %{ $saila{$pid} }) {
        my $sid = $saila{$pid};
	    next if $pid eq $sid;
        # fixing driver ids as they can be aliases
	    exists($rpgns->{$pid}) && do {
            # if (exists($rpgns->{$sid})) { # keep $sid as standard gene id and append $pid data
            # } else { # rename $pid to $sid and keep its data
            exists($rpgns->{$sid}) || do {
                $rpgns->{$sid} = $rpgns->{$pid};
            };
            delete($rpgns->{$pid});
	    };
        # unaliasing graph
	    exists($graph->{$pid}) && do {
            if (exists($graph->{$sid})) { # keep $sid as standard gene id and append $pid data
                @tary = keys %{ $graph->{$pid}{'ADJLST'} };
                foreach my $kid (@tary) {
                    if (exists($graph->{$sid}{'ADJLST'}{$kid})) {
                        foreach my $lbl (keys %{ $graph->{$pid}{'ADJLST'}{$kid} }) {
                            if (exists($graph->{$sid}{'ADJLST'}{$kid}{$lbl})) {
                                $graph->{$sid}{'ADJLST'}{$kid}{$lbl}[0] += shift @{ $graph->{$pid}{'ADJLST'}{$kid}{$lbl} };
                                push @{ $graph->{$sid}{'ADJLST'}{$kid}{$lbl} }, @{ $graph->{$pid}{'ADJLST'}{$kid}{$lbl} };
                            } else {
                                $graph->{$sid}{'ADJLST'}{$kid}{$lbl} = $graph->{$pid}{'ADJLST'}{$kid}{$lbl};
                            };
                            delete($graph->{$pid}{'ADJLST'}{$kid}{$lbl});
                        };
                    } else {
                        $graph->{$sid}{'ADJLST'}{$kid} = $graph->{$pid}{'ADJLST'}{$kid};
                    };
                    delete($graph->{$pid}{'ADJLST'}{$kid});
                };
            } else { # rename $pid to $sid and keep its data
                $graph->{$sid} = $graph->{$pid};
            };
            delete($graph->{$pid});
	    };
        # # unaliasing inverse graph
	    # exists($hparg->{$pid}) && do {
        #     if (exists($hparg->{$sid})) { # keep $sid as standard gene id and append $pid data
        #         foreach my $kid (keys %{ $hparg->{$pid}{'ADJLST'} }) {
        #             if (exists($hparg->{$sid}{'ADJLST'}{$kid})) {
        #                 foreach my $lbl (keys %{ $hparg->{$pid}{'ADJLST'}{$kid} }) {
        #                     if (exists($hparg->{$sid}{'ADJLST'}{$kid}{$lbl})) {
        #                         $hparg->{$sid}{'ADJLST'}{$kid}{$lbl}[0] += shift @{ $hparg->{$pid}{'ADJLST'}{$kid}{$lbl} };
        #                         push @{ $hparg->{$sid}{'ADJLST'}{$kid}{$lbl} }, @{ $hparg->{$pid}{'ADJLST'}{$kid}{$lbl} };
        #                     } else {
        #                         $hparg->{$sid}{'ADJLST'}{$kid}{$lbl} = $hparg->{$pid}{'ADJLST'}{$kid}{$lbl};
        #                     };
        #                     delete($hparg->{$pid}{'ADJLST'}{$kid}{$lbl});
        #                 };
        #             } else {
        #                 $hparg->{$sid}{'ADJLST'}{$kid} = $hparg->{$pid}{'ADJLST'}{$kid};
        #             };
        #             delete($hparg->{$pid}{'ADJLST'}{$kid});
        #         };
        #     } else { # rename $pid to $sid and keep its data
        #         $hparg->{$sid} = $hparg->{$pid};
        #     };
        #     delete($hparg->{$pid});
	    # };
        ## };
    };
    # adding alias list to graph nodes
    foreach my $pid (keys %{ $graph }) {
        $graph->{$pid}{'ALIASES'} = [ keys %{ $alias->{$pid} } ];
        my $nchlds = scalar ( keys %{ $graph->{$pid}{'ADJLST'} } );
        $graph->{$pid}{'CHILDnum'} = $nchlds;
    };

    %$hparg = ();
    foreach my $pid (keys %{ $graph }) {
        foreach my $kid (keys %{ $graph->{$pid}{'ADJLST'} }) {
            $hparg->{$kid}{'ADJLST'}{$pid} = $graph->{$pid}{'ADJLST'}{$kid};
        };
    };
    foreach my $pid (keys %{ $hparg }) {
        my $nchlds = scalar ( keys %{ $hparg->{$pid}{'ADJLST'} } );
        $hparg->{$pid}{'CHILDnum'} = $nchlds;
    };
   
    printf STDERR "#--> UNALIAS GRAPH (POST):  %d Child  %d Parent  %d Total NODES  %d EDGES\n".
        "#--> UNALIAS HPARG (POST):  %d Child  %d Parent  %d Total NODES  %d EDGES\n".
        "#--> UNALIAS DVgenes (POST):  %d GENE IDs\n",
        &count_nodes($graph), &count_edges($graph),
        &count_nodes($hparg), &count_edges($hparg),
        scalar(keys %$rpgns)
        if $_verbose{'RAW'};
    print STDERR join(" :: ", (keys %$rpgns)), "\n" if $_verbose{'RAW'};

    print STDERR "### UNALIASING GRAPH GENE IDS DONE.\n" if $_verbose{'RAW'};

    print STDERR "### GRAPH STRUCTURE:\n",
                 Data::Dumper->Dump([ $graph ], [ qw( *GRAPH ) ]),"\n" if $DEBUG;
    print STDERR "### HPARG STRUCTURE:\n",
                 Data::Dumper->Dump([ $hparg ], [ qw( *HPARG ) ]),"\n" if $DEBUG;

} # unalias_graph_ids

sub count_interactions_by_type($$$) {
    my ($G, $A, $B) = @_;
    my ($tot, $phy, $gen, $unk) = (0) x 4;
    # my $flg = defined($R) ? 1 : 0;
    my %R = ('P' => [], 'G' => [], 'U' => []); # if $flg
    exists($G->{$A}{'ADJLST'}{$B}) && do {
        my $rf = $G->{$A}{'ADJLST'}{$B};
        foreach my $ie (keys %$rf) {
            my ($T, $C, %h, @t);
            $T = substr($ie,1,1);
            next unless defined($rf->{$ie});
            $C = 0; %h = ();
            $rf->{$ie}[0] > 0 && do {
                @t = @{ $rf->{$ie} };
                shift @t;
                foreach my $co (@t) { # making evidences unique!!!
                    my $CO = $ie.' '.$co;
                    $h{$CO}++;
                    $C++ if $h{$CO} == 1;
                };
            };
            push @{ $R{$T} }, keys %h if $C > 0;
          THYSUM: {
              $T eq 'P' && ($phy += $C, last THYSUM); # $rf->{$ie}[0]
              $T eq 'G' && ($gen += $C, last THYSUM); # $rf->{$ie}[0]
              $T eq 'U' && ($unk += $C, last THYSUM); # $rf->{$ie}[0]
            }; # THYSUM
        };
        $tot = $phy + $gen + $unk;
    };
    # $flg && do
    unshift @{ $R{'P'} }, $phy;
    unshift @{ $R{'G'} }, $gen;
    unshift @{ $R{'U'} }, $unk;
    $G->{$A}{'ADJLST'}{$B} = { 'T' => $tot, %R };
    return ($tot, $phy, $gen, $unk); # total + 1, phy, gen, unk
    
} # count_interactions_by_type
