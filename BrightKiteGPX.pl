#!/usr/bin/perl

use LWP::UserAgent;
use URI::URL;
use HTTP::Request;

die "usage: <brightkite user>\n" if($#ARGV < 0);

dbmopen(%db, $ENV{'HOME'} . '/.bkhistory.' . $ARGV[0], 0666);
my $count = keys %db;
warn "Loaded $count cached entries.\n";

my $geturl = "http://brightkite.com/people/$ARGV[0]/objects.rss?limit=100";
my $agent = 'Mozilla/4.61 [en] (Win98; I)';

sub GetUrl {
	my ($geturl) = @_;
	my $ua = new LWP::UserAgent;
	my $request;

	my $url = new URI::URL($geturl);

	$request = new HTTP::Request('GET', $url);

	$request->header('User-Agent', $agent);

	my $response = $ua->request($request, undef, undef);

	if($response->is_success) {
		#my $str = $response->as_string;
		my $str = $response->content();
		return($str);
	} else {
		#if($debug) {
		#	print $response->code . "\n";
		#	my $str = $response->as_string;
		#	print $str . "\n";
		#}
		return("");
	}
}

my $str = GetUrl($geturl);
die "Can't download data for $ARGV[0]\n" if($str eq "");

my $lat = 0;
my $long = 0;
my $timestamp = 0;
my $name = '';
my $comment = '';

my $skipped = 0;
my $newEntries = 0;

# Parse GeoFeed

my @lines = split(/[\r\n]+/, $str);
foreach my $line (@lines) {
	$lat = $1 if($line =~/<geo:lat>([^<]*)/);
	$long = $1 if($line =~ /<geo:long>([^<]*)/);
	$timestamp = $1 if($line =~ /<bk:timestamp>([^<]*)/);
	$name = $1 if($line =~ /<bk:placeName>([^<]*)/);
	$comment = $1 if($line =~ /<guid>([^<]*)/);
	if($line =~ /<\/item>/) {
		if($comment ne '' && defined($db{$comment})) {
			$skipped++;
			$name = '';
			$comment = '';
			next;
		}

		my @timeData = gmtime($timestamp);
		my $y = $timeData[5] + 1900;
		my $mon = sprintf "%02d", $timeData[4] + 1;
		my $d = sprintf "%02d", $timeData[3];
		my $h = sprintf "%02d", $timeData[2];
		my $m = sprintf "%02d", $timeData[1];
		my $s = sprintf "%02d", $timeData[0];

		my $entry = '';
		$entry = "<trkpt lat=\"$lat\" lon=\"$long\">\n";
		$entry .= "<time>$y-$mon-$d" . "T$h:$m:$s" . "Z</time>\n";
		$entry .= "<name>$name</name>\n" if($name ne '');
		$entry .= "<cmt>$comment</cmt>\n" if($comment ne '');
		$entry .= "</trkpt>\n";

		$db{$comment} = $entry if($comment ne '');
		$newEntries++;
		$name = '';
		$comment = '';
	}
}

warn "Loaded $newEntries new entries.\n";
warn "Skipped $skipped duplicate entries.\n";

# Create GPX file from cached entries

print("<?xml version=\"1.0\" standalone=\"yes\"?>\n");
print("<gpx version=\"1.0\" creator=\"BrightKiteGPX 1.0\"");
print(" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"");
print(" xmlns=\"http://www.topografix.com/GPX/1/0\"");
print(" xmlns:topografix=\"http://www.topografix.com/GPX/Private/TopoGrafix/0/2\"");
print(" xsi:schemaLocation=\"http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd http://www.topografix.com/GPX/Private/TopoGrafix/0/2 http://www.topografix.com/GPX/Private/TopoGrafix/0/2/topografix.xsd\">\n");
my @timeData = gmtime(time);
my $y = $timeData[5] + 1900;
my $mon = sprintf "%02d", $timeData[4] + 1;
my $d = sprintf "%02d", $timeData[3];
my $h = sprintf "%02d", $timeData[2];
my $m = sprintf "%02d", $timeData[1];
my $s = sprintf "%02d", $timeData[0];
print "<time>$y-$mon-$dT$h:$m:$s" . "Z</time>\n";

print "<trk>\n";
print "<trkseg>\n";

# sort by time
my @gpx = values %db;
my @sorted = sort {
	$a =~ /<time>([^<]*)/; my $first = $1;
	$b =~ /<time>([^<]*)/; my $second = $1;
	return $first cmp $second;
} @gpx;
foreach my $val (@sorted) {
	print "$val";
}

print "</trkseg>\n";
print "</trk>\n";
print "</gpx>\n";

dbmclose(%db);

