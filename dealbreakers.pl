#!/usr/bin/perl -w

#####################
# dealbreakers.pl
# Author: Ben Garvey
# 01/10/2011
# dealbreakers script to find taskless pending deals in Highrise by 37 Signals
#####################

use strict;

use XML::Simple;
use LWP::Simple; 

########### SET THESE VARIABLES ######################

# Url to fetch deals from
my $url 		= "https://YOURSITENAME.highrisehq.com/deals";

# API Token you received from 37 Signals
my $api_token 		= "YOURAPITOKEN";

# Whether or not to employee category filtering in a conditional statement down below.  Most will want this to be 0.
my $category_filter 	= 0;

# Filepath and name of where you want the output to go
my $output_path 	= "results.txt";

###################################################W###

my @deals 		= ();
my $x 			= 0;
my $req 		= 0;
my $requestsize = 500;
my $requests 	= 5;
my $report		= "";

my $dealbrowser = LWP::UserAgent->new();
my $request 	= "";

my $test = "";
my $dealxml = "";
my $done = 0;

while($done == 0) {
	# Retrieve the xml list of deals
	$req = $x * $requestsize;
	$request = HTTP::Request->new('GET', $url . '.xml?n=' . $req);
	$request->authorization_basic($api_token, 'x');

	$dealxml = $dealbrowser->request($request)->content;
	
	if (length($dealxml) < 100) {
		$done = 1;
	}
	else {
		writeFileText( ('deals-' . $x . '.xml') , $dealxml );
	}
	
	$x++;
}

# Join this lists together
opendir(DIRECTORY, '.')
	or die "Can't open current directory.";
print join(', ', readdir(DIRECTORY));
closedir DIRECTORY;

my $dealtext = "";

# Find the files we just saved and group them into one file
for($x=0; $x<$requests; $x++) {
	my $d = getFileText('deals-' . $x . '.xml');
	if (length($d) > 100) {
		if ($d =~ /(<\?xml version="1\.0" encoding="UTF-8"\?>)\n(<deals type="array">)(.*)(<\/deals>)/igcs) {
			$d = $3;
		}
		
		$dealtext .= $d;
	}
}

$dealtext = 	'<?xml version="1.0" encoding="UTF-8"?>
				 <deals type="array">' . "$dealtext" . '</deals>';

writeFileText('deals.xml', $dealtext);

# Get list of deals
my $file = 'deals.xml';
my $xs1 = XML::Simple->new();
my $doc = $xs1->XMLin($file);

# Build list of the deals
foreach my $key (keys (%{$doc->{deal}})) {

	# Temporary deal hash
	my %d = ();  
	
	my $id 				= $doc->{deal}->{$key}->{'id'}->{'content'};
	my $name 			= $key;
	$d{'id'} 			= $id;
	$d{'status'}		= $doc->{deal}->{$key}->{'status'};

	# Put the deal in an array
	push(@deals, \%d);
}


# An array of broken deals
my @taskless_deals = ();

# Loop through all deals and check to see if they are broken
foreach my $deal (@deals) {

	# Pull out the id number of the deal
	my @keys = keys(%{$deal});
	my $k = $keys[0];

	# Retrive a deal
	my $browser = LWP::UserAgent->new();
	my $req = HTTP::Request->new('GET', $url . '/' . $k);
  	$req->authorization_basic($api_token, 'x');
	
	# HTML of the deal.  We're doing this because the tasks don't show up in the deal's xml feed.
	my $html = $browser->request($req)->as_string . "\n";

	# Is it pending?
	#my $pending_string = "<input id=\"status_name\" name=\"status[name]\" type=\"hidden\" value=\"pending\" />";
	my $task_string = "class=\"task show_task\"";

	my $html2 = $html;
	
	if ($html =~ /value="pending"/igc) {

		# Is it's category something other than "Customer Review"?
		# Note:  We use categories as a separate project status field. 
		if ($html2 !~ /Customer Review/igc && $category_filter == 1) {

			#print $html . "\n";
		
			# Does it have a task?
			if ($html !~ /$task_string/igc) {
	
				#print " and has no tasks";
	
				# If not, add it to the list
				push(@taskless_deals, $k);
			}
			else {
				#print " but has tasks";
			}

		}

		#print "\n";
	}
	else {
		#print "$k is not pending\n";
	}

}

$report .= "The are " . scalar(@taskless_deals) . " broken deals.\n\n";

foreach my $x (@taskless_deals) {
	#print $url . "/" . $x\n";
	$report .= $url . "/" . "$x\n";
}

print $report;
writeFileText($output_path, $report);


# Private subroutine that accepts a filename as a string and returns the contents of that file
sub writeFileText {

	my $filepath = $_[0];
	my $contents = $_[1];

	# Open the file
	open(FILEHANDLE, ">$filepath") or
		die ("Cannot open $filepath");

	my $text = "";
	my $newtext = "";

	print FILEHANDLE $contents;

	print "saving text to $filepath...\n";

	close FILEHANDLE;	
}

