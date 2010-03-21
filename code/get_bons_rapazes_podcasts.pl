#!/usr/bin/env perl

use strict;
use warnings;

use IPC::Run qw( start timeout );


my @podcasts;
while(<STDIN>) {
	my($line) = $_;
	chomp($line);
	while( $line =~ /(mms:[^"]+)"/igs  ) {
		push @podcasts, $1;
		print "$1 \n";
	}
}
#print "exiting\n";
#exit(1);

my $fname = '';
my $cmd = "mplayer -dumpstream -dumpfile";
foreach(@podcasts) {
	$_ =~ m!.+-(\d+.wma)!;
	my $fname = "bonsrapazes_$1";
	if( -e $fname ) {
		print "$fname exists, skipping!\n";
		next;
	}
	print " running:\n$cmd $fname $_\n";
	start "$cmd $fname $_";
}

print "All fetched!!"
