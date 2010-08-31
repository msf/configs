#!/usr/bin/perl
#
# finddup.pl v0.1
# Find duplicate files
# Filipe Almeida <filipe.almeida@gmail.com>
#

use File::Find;
use Digest::MD5;

our %file_size;

sub process_size {
	-f or return;
	my $size = (lstat($_))[7];
	push @{$file_size{$size}}, $_;
}

sub find_dup {
	my %hash;
	for(@_) {
		open FILE, $_ or next;
		my $ctx = Digest::MD5->new;
		$ctx->addfile(FILE);
		push @{$hash{$ctx->hexdigest}}, $_;
		close FILE;
	}

	for(keys %hash) {
		my @list = @{$hash{$_}};
		if($#list > 0) {
			printf join("\n", @list),"\n";
			print "\n\n";
		}
	}

}


find({wanted => \&process_size, no_chdir => 1}, '.');

delete $file_size{0};

for(keys %file_size) {
	my @list = @{$file_size{$_}};
	find_dup @list if $#list > 0;
}
