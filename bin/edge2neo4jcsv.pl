#!/usr/bin/perl
#
=head1 NAME

edge2neo4jcsv.pl
graphcompare - A command-line tool to compare graph files
               in DOT or tabular format.


=head1 SYNOPSIS

    edge2neo4jcsv.pl   -wholegraph FILE \
                       -alias FILE \
                       -biogrid FILE \
                       -string FILE \
                       -ppaxe FILE \
                       -maxlvl INT \
                       -prefix PREFIX


=head1 OPTIONS

=over 8

=item B<-h>, B<-help>

Help shows the options and requirements needed for the program to work.


=item B<-w>, B<-wholegraph> <FILE>

REQUIRED. Wholegraph file is a required graph file (DOT or graphviz)
created by filter_interactions_to_graph2.pl.


=item B<-j>, B<-json> <FILE>

REQUIRED. Wholegraph JSON file is a required graph file
created by filter_interactions_to_graph2.pl.


=item B<-m>, B<-maxlvl> <INT>

REQUIRED. Is an integer that represents the max level graph created,
that is not the wholegraph, from the filter_interactions_to_graph2.pl
program. This value can be acquiered by looking at the folder where
the graphs are stored and finding the highest number after "graph_lvl+".


=item B<-pr>, B<-prefix> <PREFIX>

REQUIRED. This contains the prefix of the graph level files.
Example: "all_graph_lvl+".


=item B<-v>, B<-verbose>

OPTIONAL. Verbose option gives extra information in the log files.
May be beneficial when trying to debug a problem


=item B<-o>, B<-output> <FILE>

REQUIRED. Output CSV file.


=back

=head1 FUNCTIONS

=cut

use warnings;
use strict;
use JSON::Parse "json_file_to_perl";
use Getopt::Long qw(:config no_ignore_case);
use Data::Dumper;
use Pod::Usage;


# ------------------------------------------------------------------------
=over 2

=item get_cmdline_arguments()

Reads command line arguments

=back
=cut
sub get_cmdline_arguments {
  # INPUTS:
  #     whole_graph_file
  #     interaction_prefix
  #     max_lvl
  #     interaction_type_file
  #     interaction_source_file
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
    'aliasfile=s',
    'wholegraph=s',
    'json=s',
    'maxlvl=s',
    'prefix=s',
    'output=s'
  );

  # Print help if -help option
  if (defined $options->{'help'}){
    pod2usage(
      -verbose => 1,
      -output => \*STDOUT
    );
  }
  my @required = qw( wholegraph json maxlvl prefix output );
  foreach my $req (@required) {
    defined $options->{$req}
      or die "\n# Command line option $req is missing!\n";
  }
  return;
}


# -----------------------------------------------------------------------------
=over 2

=item init_graph()

Initializes whole graph

=back
=cut

sub init_graph {
  my $wholegraph = shift;
#  my $alias      = shift;
  my $maxlvl     = shift;
  my $verbose    = shift;

  print STDERR "\tReading graph file: ", $wholegraph, " ...\n"
      if $verbose;

  my %data       = ();
  open (my $fh, "<$wholegraph")
    or die "Can't read $wholegraph : $!\n";

  my $n = 0;
  while (my $line = <$fh>) {
    my $interacts;
    chomp($line);
    next unless $line =~ m/->/;
    ($interacts, undef) = split /\s*[\[;]/o, $line;
    my @F = split /->/o, $interacts;
    print STDERR "\n## NOT BINARY: $interacts\n"
        if scalar(@F) != 2;
    my ($gene1, $gene2) = @F[0,1];
    $gene1 = gene_cleaner($gene1);
    $gene2 = gene_cleaner($gene2);
    my $interaction = $gene1 . "->" . $gene2;
    #print STDERR "WG#-> $line\n".
    #             "#---I: ::${interacts}::\n".
    #             "#---N: ::${interaction}::\n";
    next if exists $data{$interaction};
    $data{$interaction} = {
          "strength"             => 0,
          "level"                => $maxlvl + 1,
          "genetic_interaction"  => 0,
          "physical_interaction" => 0,
          "unknown_interaction"  => 0,
          "biogrid"              => 0,
          "string"               => 0,
          "ppaxe"                => 0,
          "string_score"         => [], # array
          "ppaxe_score"          => [], # array
          "biogrid_pubmedid"     => [], # array
          "string_pubmedid"      => [], # array
          "ppaxe_pubmedid"       => [], # array
          "string_evidence"      => []  # array
    }; # might need to add a biogrid score if there is one
  }; # while
  print STDERR "\n...done.\n" if $verbose;
  return \%data;
}; #init_graph


# ------------------------------------------------------------------------
=over 2

=item gene_cleaner()

Removes non-valid characters from genes by taking
only the symbol between quotes.

=back
=cut
sub gene_cleaner {
  my $dirty_gene = uc(shift);
  $dirty_gene =~ s/[\s\";]//g;
  return $dirty_gene

}; #gene_cleaner

# ------------------------------------------------------------------------
=over 2

=item json_cleaner()

Removes non-valid characters from genes by taking
only the symbol between quotes.

=back
=cut
sub json_cleaner {
  my $dirty_json = shift;
  $dirty_json =~ s/[\s\';]//g;
  return $dirty_json

}; #json_cleaner

# ------------------------------------------------------------------------
=over 2

=item PMID_cleaner()

Removes non-valid characters from genes by taking
only the symbol between quotes.

=back
=cut
sub PMID_cleaner {
  my $dirty_pmid = shift;
  $dirty_pmid =~ s/PMID//g;
  return $dirty_pmid

}; #PMID_cleaner

# ------------------------------------------------------------------------
=over 2

=item string_cleaner()

Removes non-valid characters from genes by taking
only the symbol between quotes.

=back
=cut
sub string_cleaner {
  my $dirty_string = shift;
  $dirty_string =~ s/.*\((.*)\)/$1/;
  return $dirty_string

}; #string_cleaner

# -----------------------------------------------------------------------------
sub get_level {
  # INPUTS: filename, data structure
  my $prefix  = shift;
  my $maxlvl  = shift;
  my $data    = shift;
  my $verbose = shift;
  print STDERR "\tAdding interaction level... \n" if $verbose;

  for my $currlvl (0..($maxlvl)) {
    my $filename = $prefix . $currlvl . ".dot";
    open (my $fh, "<$filename")
      or die "Cannot open $filename!\n";
#    print STDERR "\n\t\tReading lvl file $filename ...\n" if $verbose;
    my $n = 0;
    while (my $line = <$fh>) {
      my $interacts;
      chomp($line);
      next unless $line =~ m/->/;
      ($interacts, undef) = split /\s*[\[;]/o, $line;
      my @F = split /->/, $interacts;
      scalar(@F) != 2 &&
         print STDERR "\n## NOT BINARY: $interacts\n" if $verbose;
      my ($gene1, $gene2) = @F[0,1];
      $gene1 = gene_cleaner($gene1);
      $gene2 = gene_cleaner($gene2);

      my ($interaction,$interaction1);
      $interaction1 = $gene1 . "->" . $gene2;

      if (exists $data->{$interaction1}) {
        $interaction = $interaction1;
      } else {
        print STDERR "\n\t\t[WARNING] Missing interaction".
                     " in level $currlvl file: $interaction1 \n"
              if $verbose;
        next;
      };
      #print STDERR "LVL $currlvl#-> $line\n".
      #             "#---I: ::${interacts}::\n".
      #             "#---N: ::${interaction}::\n";

      if ($currlvl < ($data->{$interaction}{"level"})) {
        $data->{$interaction}{"level"} = $currlvl;
      };
      #  if ($data->{$interaction}{"level"} == ($maxlvl + 1)) {
      #     $data->{$interaction}{"level"} = $currlvl ;
      #  }
    };
  };
  print STDERR "\n...done.\n" if $verbose;
  return;
}; # get_level
# -----------------------------------------------------------------------------
sub filter_json {
  my $wholegraph = shift;
  my $data       = shift;
  my $verbose    = shift;
  print STDERR "\tFiltering JSON...\n" if $verbose;

  my $json = json_file_to_perl("$wholegraph");
    map {
        my $k = $_->{'data'};
        my $gene1 = $k->{'srclbl'};
        my $gene2 = $k->{'tgtlbl'};
        my $interaction = $gene1 . "->" . $gene2;
        if (exists ($data->{$interaction})) {
          $data->{$interaction}{"strength"} = $k->{'strength'};
          $data->{$interaction}{"physical_interaction"} =
                 @{ $k->{'evidences'}{'physical'} }[0];
          my @a = @{$k->{'evidences'}{'physical'}};
          foreach (@a[1..$#a]) {
            if (m/BIOGRID/) {
              $data->{$interaction}{"biogrid"}++;
              my($P, $type, $source, $score, $PMID);
              ($P, $type, $source, $score, $PMID, undef) = split /\s/, $_;
              if ($PMID) {
                  push(@{ $data->{$interaction}{"biogrid_pubmedid"} }, json_cleaner($PMID));
              }
            }
            if (m/STRING/) {
              $data->{$interaction}{"string"}++;
              my($P, $source, $score, $type, @evidence) = split /\s/, $_;
              push(@{ $data->{$interaction}{"string_score"} },
                   json_cleaner($score));
              foreach (@evidence) {
                if (m/PMID/) {
                  push(@{ $data->{$interaction}{"string_pubmedid"} },
                       PMID_cleaner($_));
                } else {
                  push(@{ $data->{$interaction}{"string_evidence"} },
                       string_cleaner($_));
                }
              }
            }
          }
          $data->{$interaction}{"genetic_interaction"} =
                 @{ $k->{'evidences'}{'genetic'} }[0];
          my @b = @{$k->{'evidences'}{'genetic'}};
          foreach (@b[1..$#b]) {
            if (m/BIOGRID/) {
              $data->{$interaction}{"biogrid"}++;
              my($G, $type, $source, $score, $PMID, undef
                 ) = split /\s/, $_;
              push(@{ $data->{$interaction}{"biogrid_pubmedid"} },
                   json_cleaner($PMID));
            }
          }
          $data->{$interaction}{"unknown_interaction"} =
                 @{ $k->{'evidences'}{'unknown'} }[0];
          my @c = @{$k->{'evidences'}{'unknown'}};
          #print STDERR Dumper(\@c);
          foreach (@c[1..$#c]) {
            if (m/BIOGRID/) {
              $data->{$interaction}{"biogrid"}++;
              my($U, $type, $source, $score, $PMID, undef
                 ) = split /\s/, $_;
              push(@{ $data->{$interaction}{"biogrid_pubmedid"} }, $PMID);
            }
            if (m/PPaxe/) {
              $data->{$interaction}{"ppaxe"}++;
              my($U, $source, $score, $PMID, undef) = split /\s/, $_;
              push(@{ $data->{$interaction}{"ppaxe_score"} },
                   gene_cleaner($score));
              push(@{ $data->{$interaction}{"ppaxe_pubmedid"} },
                   gene_cleaner($PMID));
            }
          }
        } else {
        print STDERR "ERROR retrieving data\n";
        }
      } @{ $json->{"edges"} };
#
#  map {
#    my $k = $_->{'data'};
#    print STDERR join(",",
#                      $k->{'srclbl'},
#                      $k->{'tgtlbl'},
#                      $k->{'strength'},
#                      join("//",'[P]', @{ $k->{'evidences'}{'physical'} },
#                                '[G]', @{ $k->{'evidences'}{'genetic'} },
#                                '[U]', @{ $k->{'evidences'}{'unknown'} })
#                      )."\n"
#  } @{ $json->{"edges"} };
  print STDERR "\n...done.\n" if $verbose;
  return $data;
}; #filter_json

#my $lvl0 = json_file_to_perl();

# ------------------------------------------------------------------------
=over 2

=item print_csv()

Explain format for CSV/NEO4j

=back
=cut
sub print_csv {
  my $data    = shift;
  my $output  = shift;
  my $verbose = shift;
  print STDERR "\tPrinting csv to $output ... " if $verbose;

  open (my $fh, ">$output")
    or die "Cannot open $output!\n";
  print $fh "gene_1;gene_2;level;strength;genetic_interaction;".
            "physical_interaction;unknown_interaction;biogrid;".
            "biogrid_pubmedid;string;ppaxe;ppaxe_score;ppaxe_pubmedid\n";
  foreach my $interaction (keys %$data) {
    my ($gene1, $gene2) = split /->/, $interaction;
    # Skip interactions not present in biogrid OR string OR ppaxe
    if ($data->{$interaction}{"biogrid"} + $data->{$interaction}{"string"}
        + $data->{$interaction}{"ppaxe"} == 0) {
      print STDERR "NOT FOUND: $interaction\n";
      next;
    }
    print $fh "$gene1", ";", "$gene2";
    foreach my $attribute (qw(level strenth genetic_interaction
                              physical_interaction unknown_interaction biogrid biogrid_pubmedid string
                              ppaxe ppaxe_score ppaxe_pubmedid)) {

      if (ref($data->{$interaction}{$attribute}) eq 'ARRAY') {
        if (not scalar(@{ $data->{$interaction}{$attribute}})) {
          print $fh ";NA";
        } else {
            print $fh ";", join(",", @{ $data->{$interaction}{$attribute}});
        }
      } else {
        if (not defined $data->{$interaction}{$attribute}) {
          print $fh ";NA";
        } else {
          print $fh ";$data->{$interaction}{$attribute}";
        }
      }
    }
    print $fh "\n";
  }
  close($fh);

  print STDERR "done.\n" if $verbose;
  return;
}; #print_csv

# -----------------------------------------------------------------------------
=over 2

=item print_short_csv()

Explain format for CSV/NEO4j

=back
=cut
sub print_short_csv {
  my $data    = shift;
  my $output  = shift;
  my $verbose = shift;
  print STDERR "\tPrinting csv to $output ... " if $verbose;

  open (my $fh, ">$output")
    or die "Cannot open $output!\n";
  print $fh "gene_1,gene_2,level\n";
  foreach my $interaction (keys %$data) {
    my ($gene1, $gene2) = split /->/, $interaction;
    # Skip interactions not present in biogrid OR string OR ppaxe
#    if ($data->{$interaction}{"biogrid"} + $data->{$interaction}{"string"}
#        + $data->{$interaction}{"ppaxe"} == 0) {
#      print STDERR "NOT FOUND: $interaction\n";
#      next;
#    }
    print $fh "$gene1", ",", "$gene2";
    foreach my $attribute (qw( level )) {
      print $fh ",$data->{$interaction}{$attribute}";
    }
    print $fh "\n";
  }
  close($fh);

  print STDERR "done.\n" if $verbose;
  return;
}; #print_csv

# -----------------------------------------------------------------------------
# MAIN PROGRAM
my %options;
get_cmdline_arguments(\%options);

# START REPORT
my $start_time   = time();
my $current_time = localtime();

print STDERR "\nPROGRAM STARTED\n",
            "\tProgram         edge2neo4jcsv.pl \n",
            "\tVersion         v0.1.0\n",
            "\tStart time      $current_time\n\n" if $options{'verbose'};

my $data = init_graph($options{'wholegraph'},
                      $options{'maxlvl'},
                      $options{'verbose'});
get_level($options{'prefix'}, $options{'maxlvl'}, $data, $options{'verbose'});
filter_json($options{'json'}, $data, $options{'verbose'});
#print STDERR Dumper(\$data);
print_csv($data, $options{'output'}, $options{'verbose'});
#print_short_csv($data, $options{'output'}, $options{'verbose'});

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
};
