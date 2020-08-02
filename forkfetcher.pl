#!/usr/bin/perl
use v5.26;
use strict;
use warnings;
use LWP::Simple;
use HTML::TreeBuilder;
use Data::Dumper;

my $browser=LWP::UserAgent->new;
my @headers=("User-Agent"=>"Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:66.0) Gecko/20100101 Firefox/66.0");
my $forkurl = "https://github.com/REPOSITORY/network/members";

my $debug = undef;

sub run { if(defined $debug) { say @_; } else { system @_; } }

sub error {
	my ($returncode, $message) = @_;
	say "ERROR $returncode: $message";
	exit $returncode;
}

#fetch a page and return it as HTML::Element
sub fetchpage {
	my $url = shift;
	my $response = $browser->get($url, @headers);
	error(2, "Couldn't fetch '$url'") unless($response->is_success);
	error(3, "The page $url is no regular html") unless($response->content_type eq "text/html");
	return HTML::TreeBuilder->new_from_content($response->content);
}

#fetch the page with all the forks and return <div id="network"> and it's contents as HTML::Element
#or undef if there are no forks yet
sub fetchforkpage {
	$_ = $forkurl;
	s/REPOSITORY/$ARGV[0]/;
	my $netid = fetchpage($_)->look_down("id", "network");
	return undef unless(defined $netid);
	return $netid;
}

#Return a arrayref of all forks in format "username/forkname" based on the html found with fetchforkpage
sub searchforklist {
	my @forks = ();
	my $netid = fetchforkpage;
	return [] unless(defined $netid);
	foreach($netid->look_down( _tag => "a")) {
		push(@forks, $1) if($_->attr("href") =~ /^\/(\S+\/\S+)$/ and not $_->attr("href") =~ /\/$ARGV[0]/);
	}
	return \@forks;
}

#add all forks found with searchforklist
sub addremotes {
	my $remotes = searchforklist;
	$_ = shift @$remotes;
	run "git remote add upstream https://github.com/$_";
	foreach(@$remotes) {
		/(\S+)\/\S+/;
		run "git remote add $1 https://github.com/$_";
	}
}

error(1, "Provide 'yourusername/reponame' as argument") unless(@ARGV==1);
unless( -f ".git/config") {
	my $dir = $ARGV[0]; $dir=~s/.*\///;
	unless( -d $dir ) {
		run "git clone git\@github.com:$ARGV[0].git";
	}
	chdir $dir;
}
addremotes;
