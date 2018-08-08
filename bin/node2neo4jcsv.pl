#!/usr/bin/perl
=head1 NAME

edge_maker.pl
graphcompare - A command-line tool to compare graph files in DOT or tabular format.


=head1 SYNOPSIS

    node_maker.pl   -wholegraph FILE \
                    -alias FILE \
                    -nvariants FILE \
                    -drivers FILE \
                    -maxlvl INT \
                    -prefix PREFIX \
                    -verbose (optional)\
                    -output OUTPUT



=head1 OPTIONS

=over 5

=item B<-w>, B<-wholegraph> <FILE>

REQUIRED. Wholegraph file is a required graph file (DOT or graphviz)
created by filter_interactions_to_graph2.pl.


=item B<-a>, B<-alias> <FILE>

REQUIRED. Inheritance file that contains the driver genes, their inheritance
pattern code and their syndromic code.


=item B<-n>, B<-nvariants> <FILE>

OPTIONAL. The nvariants file is the file that contains all genes and the number
of variants.


=item B<-d>, B<-drivers> <FILE>

REQUIRED. Inheritance file that contains the driver genes, their inheritance
pattern code and their syndromic code.

=item B<-pr>, B<-prefix> <PREFIX>

REQUIRED. This contains the prefix of the graph level files. Example: "all_graph_lvl+".


=item B<-m>, B<-maxlvl> <INT>

REQUIRED. The max level is the highest number after the plus sign of the
graph_lvl+ dot files created by the filter_interactions_to_graph2.pl program.


=item B<-v>, B<-verbose>

OPTIONAL. Verbose option gives extra information in the log files. May be
beneficial when trying to debug a problem


=item B<-o>, B<-output> <FILE>

REQUIRED. Output CSV file.


=item B<-h>, B<-help>

Shows help menu.


=back

=head1 FUNCTIONS

=cut

use warnings;
use strict;
use Getopt::Long qw(:config no_ignore_case);
use Data::Dumper;
use Pod::Usage;

# -----------------------------------------------------------------------------
=over 2

=item get_cmdline_arguments()

Reads command line arguments

=back
=cut
sub get_cmdline_arguments {
  # INPUTS:
  #     wholegraph_file
  #     alias_file
  #     nvariants_file
  #     drivers_file
  #     prefix
  #     max_lvl
  #     verbose
  #     output
  # OPTIONS:
  #     \%options
  my $options = shift;

  # Print synopsis if no arguments
  pod2usage(
      -verbose => 0,
      -output => \*STDOUT
    ) if (!@ARGV);

  GetOptions(
    $options,
    'help|?',
    'verbose|?',
    'wholegraph=s',
    'alias=s',
    'nvariants=s',
    'drivers=s',
    'prefix=s',
    'maxlvl=s',
    'output=s'
  );

  # Print help if -help option
  if (defined $options->{'help'}){
    pod2usage(
      -verbose => 1,
      -output => \*STDOUT
    );
  }
  my @required = qw( wholegraph alias drivers prefix maxlvl output );
  foreach my $req (@required) {
    defined $options->{$req}
      or die "\n# Command line option $req is missing!\n";
  }
  return;
}; # get_cmdline_arguments

#---------------------------------------------------------------
=over 8

=item create_data_set()

Initializes whole graph and creates a dataset framework.

=back
=cut

sub create_data_set {
  my $wholegraph    = shift;
  my $alias = shift;
  my $maxlvl  = shift;
  my %data    = ();

  open (my $fh, "<", $wholegraph)
    or die "Can't read $wholegraph : $!\n";

  my $n = 0;
  my $first = <$fh>;
  while (my $line = <$fh>) {
    chomp($line);
#    next unless $line =~ m/->/;
    next if $line =~ m/graph/;
    next if $line =~ m/node/;
    my ($interacts) = split /\s*\[/, $line;
    #print "$interacts\n";
    if ($interacts =~ /->/) {
      my @F = split /->/, $interacts;
      print STDERR "\n## NOT BINARY: $interacts\n" if scalar(@F) != 2;
      my ($gene1, $gene2) = @F[0,1];
      $gene1 = quote_cleaner($gene1);
      $gene2 = quote_cleaner($gene2);
#      $gene1 = check_aliases($alias,$gene1);
#      $gene2 = check_aliases($alias,$gene2);
      my @gen = ($gene1, $gene2);
#      @gen = gene_sorter(@gen);
#      print "$edge[0] -> $edge[1]\n";
      foreach my $gene (@gen){
        $data{$gene} = ();
        $data{$gene}->{"level"} = $maxlvl + 1;
        $data{$gene}->{"inheritance_pattern"} = 0;
        $data{$gene}->{"gene_disease"} = 0;
        $data{$gene}->{"nvariants"} = "NA";
      }
    } else {
      #print STDERR "$interacts\n";
#      my $gene = check_aliases($alias,$interacts);
      my $gene = quote_cleaner($interacts);
      my @gen = ($gene);
      foreach my $gen (@gen){
        $data{$gen} = ();
        $data{$gen}->{"level"} = $maxlvl + 1;
        $data{$gen}->{"inheritance_pattern"} = 0;
        $data{$gen}->{"gene_disease"} = 0;
        $data{$gen}->{"nvariants"} = "NA";
      }
    }; #this adds genes that are not interacting with anything
  }
  return \%data;
#  return \@gen;
}; # create_data_set

# -----------------------------------------------------------------------------
=over 8

=item read_IDaliases_table()

Reads the alias file created by filter_interactions_to_graph2.pl

=back
=cut

sub read_IDaliases_table {
    my ($file, $alias, $verbose) = @_;
    my $DEBUG = 0;
    my %salias = ();

    open(my $dvfile, "<", "$file")
      or die("### ERROR ### Cannot open DRIVER genes file: $file\n");
    print STDERR "### READING ALIASES DATA from: $file\n" if $verbose;

    my ($c, $n, $r) = (1, 0, '.');
    while (<$dvfile>) {

     	my ($oid,$gid,$syns);
	    $r = ".";
      next if /^\s*$/;
	    next if /^\#/;
	    chomp;
	    ($oid,undef,$syns,undef) = split /\t/, $_, 4;
	    $gid = gene_cleaner($oid);
     	print STDERR "### $oid -> $gid : $syns\n" if $DEBUG;

      if (not exists $salias{$gid}) {
        $salias{$gid} = []
      }
      #exists($salias{$gid}) || ($salias{$gid} = []);
      foreach my $syn (split /,/, $syns) {
        push @{ $salias{$gid} }, gene_cleaner($syn);
      };

	    print STDERR $r if $verbose;
	    print STDERR "[$c]\n" if ($c % 50 == 0) and $verbose;
	    $c++;

    }; # while <$dvfile>

    print STDERR "[$c]\n" if ($c-- % 50 != 0) and $verbose;

    foreach my $gid (keys %salias) {
      foreach my $syn (@{$salias{$gid}}) {
        $alias->{$syn} = $gid if not exists $salias{$syn};
        #exists($salias{$syn}) || ($alias->{$syn} = $gid);
      }
    };
    undef %salias;
    close($dvfile);

    print STDERR "### READ $c RECORDS from $file, aliases table initialized.\n" if $verbose;

}; # read_IDaliases

# -----------------------------------------------------------------------------
=over 2

=item check_aliases()

Checks if gene in question is the official name or an alias. If an alias, the
name will be changed to become the official name.

=back
=cut

sub check_aliases {
    my ($alias,$gid) = @_;
    $gid = gene_cleaner($gid);
    return exists($alias->{$gid}) ? $alias->{$gid} : $gid;
}; # check_aliases

# -----------------------------------------------------------------------------
=over 2

=item gene_cleaner()

Removes non-valid characters from genes and converts lower case characters to
upper case.

=back
=cut

sub gene_cleaner {
  my $dirty_gene = uc(shift);
  $dirty_gene =~ s/^\s*\"?\s*//og;
  $dirty_gene =~ s/\s*\"?\s*$//og;
  $dirty_gene =~ s/\W+/_/oga; # s/[\s\";]//g;
  return $dirty_gene
}; # gene_cleaner

# -----------------------------------------------------------------------------
=over 2

=item quote_cleaner()

Removes non-valid characters from genes and converts lower case characters to
upper case.

=back
=cut

sub quote_cleaner {
  my $dirty_gene = uc(shift);
  $dirty_gene =~ s/[\s\";]//g;
  return $dirty_gene

}; # gene_cleaner
# -----------------------------------------------------------------------------
=over 2

=item gene_sorter()

Makes a unique gene list to be used by data structure.

=back
=cut

sub gene_sorter {
   my %seen;
   grep !$seen{$_}++, @_;
}; # gene_sorter

# -----------------------------------------------------------------------------
=over 8

=item get_level()

Initializes whole graph

=back
=cut

sub get_level {
  # INPUTS: filename, data structure
  #my $wholegraph = shift;
  my $alias = shift;
  my $prefix = shift;
  my $maxlvl = shift;
  my $data = shift;

  for my $currlvl (0..($maxlvl)) {
      my $filename = $prefix . $currlvl . ".dot";
      open (my $fh, "<", $filename)
        or die "Cannot open $filename!\n";

#      print "$currlvl\n";

    while (my $line = <$fh>) {
      chomp($line);
      #    next unless $line =~ m/->/;
      next if $line =~ m/^\s*(digraph|graph|node|edge|\})/o;
      if ($line =~ m/->/) {
        my $genes = process_edge($line);
        foreach my $gene (@{ $genes }) {
          $data->{$gene}{"level"} = $currlvl if $currlvl < $data->{$gene}{"level"};
          #print STDERR "EDGE lvl $currlvl : $gene lvl $data->{$gene}{level}\n";
        };
      } else {
        my $node = process_node($line);
        foreach my $gene ($node) {
          $data->{$gene}{"level"} = $currlvl if $currlvl < $data->{$gene}{"level"};
#          print STDERR "NODE lvl $currlvl : $gene lvl $data->{$gene}{level}\n";
        };
      };
    };
  };
  return;
}; # get_level

# -----------------------------------------------------------------------------
sub process_node {
  my $line = shift;
  my ($dirty_node, undef) = split /\s*\[/, $line;
  my $node = gene_cleaner($dirty_node);
  return $node;
}; #process_node

# -----------------------------------------------------------------------------
sub process_edge {
  my $line = shift;

  my ($interacts, undef) = split /\s*[\[;]/, $line;
  my @F = split /->/, $interacts;
  my ($gene1, $gene2) = @F[0,1];
  $gene1 = gene_cleaner($gene1);
  $gene2 = gene_cleaner($gene2);
  my @genes = ($gene1,$gene2);
  return \@genes;
}; #process_edge

# -----------------------------------------------------------------------------
=over 8

=item get_nvariants()

Initializes whole graph

=back
=cut

sub get_nvariants {
  # INPUTS: filename, data structure
  my $nvariants = shift;
  my $data      = shift;
  my $alias     = shift;

  open (my $fh, "<", $nvariants)
      or die "Cannot open $nvariants!\n";

  while (my $line = <$fh>) {
    chomp($line);
    my ($ngene, $variant) = split /\t/, $line;
    $ngene = check_aliases($alias, $ngene);
    if (exists $data->{$ngene}) {
      $data->{$ngene}{"nvariants"} = $variant;
    }
  }

  return;
}; # get_nvariants

#-----------------------------------------------------------------------------
=over 8

=item get_drivers()

Initializes whole graph

=back
=cut

sub get_drivers {
  # INPUTS: drivers file and data structure.
  my $drivers = shift;
  my $data = shift;
  my $alias = shift;

  open (my $fh, "<", $drivers)
    or die "Cannot open $drivers!\n";

  while (my $line = <$fh>) {
    chomp($line);
    my ($gene, $inheritance, $syndrom) = split /\t/, $line;
    $gene = check_aliases($alias, $gene);
    if (exists ($data->{$gene})) {
      $data->{$gene}{"inheritance_pattern"} = $inheritance;
      $data->{$gene}{"gene_disease"} = $syndrom;
    }
  }

  return;
}; # get_drivers

#------------------------------------------------------------------------------
=over 2

=item print_csv()

Prints the dataset HASH values into a comma separated variable file

=back
=cut
sub print_csv {
  my $data    = shift;
  my $output  = shift;
  my $verbose = shift;
  print STDERR "\tPrinting csv to $output ... " if $verbose;

  open (my $fh, ">", $output)
    or die "Cannot open $output!\n";
  print $fh "identifier,level,inheritance_pattern,gene_disease,nvariants\n";
  foreach my $gene (keys %$data) {
    print $fh "$gene";
    foreach my $attribute (qw( level inheritance_pattern gene_disease nvariants )) {
      if (not defined $data->{$gene}{$attribute}) {
        print $fh ",NA";
      } else {
        print $fh ",$data->{$gene}{$attribute}";
      }
    }
    print $fh "\n";
  }
  close($fh);

  print STDERR "\n...done.\n" if $verbose;
  return;
}; # print_csv

#------------------------------------------------------------------------------
# MAIN PROGRAM
my %options;
get_cmdline_arguments(\%options);

my $start_time   = time();
my $current_time = localtime();

print STDERR "\nPROGRAM STARTED\n",
             "\tProgram             edge2neo4jcsv.pl \n",
             "\tVersion             v0.1.0\n",
             "\tStart time          $current_time\n\n" if $options{'verbose'};

my %ALIAS = ();
read_IDaliases_table($options{'alias'}, \%ALIAS, $options{'verbose'});
my $data = create_data_set($options{'wholegraph'}, \%ALIAS, $options{'maxlvl'});
#my $var = join "\n", keys $data;
#print "$var";
get_level(\%ALIAS, $options{'prefix'}, $options{'maxlvl'}, $data);
my $size = scalar keys %{ $data };
#print "$size\n";
#print Dumper(\$data);
if ($options{'nvariants'}) {
  get_nvariants($options{'nvariants'}, $data, \%ALIAS);
}
get_drivers($options{'drivers'}, $data, \%ALIAS);
print_csv($data, $options{'output'});

# END REPORT
if ($options{'verbose'}) {
  my $end_time  = time();
  $current_time = localtime();
  my $sec = $end_time - $start_time;

  my $hours = ($sec/3600) % 24;
  my $minutes = ($sec/60) % 60;
  my $seconds = $sec % 60;
  print STDERR "\nPROGRAM FINISHED\n",
               "\tEnd time \t$current_time\n\n",
               "\tJob took ~ $hours hours, $minutes minutes and $seconds seconds\n\n";
}
