#!/usr/bin/perl -w
#
# extract - extract the items in the wp xml rss feed and make wiki pages out of them
#
# Author: Tamara Temple <tamara@tamaratemple.com>
# Time-stamp: <2012-09-21 05:17:13 tamara>
# Created: 2011/10/22
# Copyright (c) 2011 Tamara Temple Web Development
#
# TODO
#  fixup_attachments
#  comments
#  more item elements

use strict;
use XML::Simple;
use Data::Dumper::Names;
use HTML::WikiConverter;
use LWP::UserAgent;
use File::Basename;
use File::Temp qw/tempfile/;

my %Attachments;
my $importdir = "imports";
mkdir($importdir);
my $uploaddir = "uploads";
mkdir($uploaddir);

my $filename = $ARGV[0];
die if $filename =~ /^$/;

my $wc = new HTML::WikiConverter(dialect => "PmWiki2");
my $ua = LWP::UserAgent->new;
$ua->timeout(10);

my $xp = XMLin($filename);

my $itemsp = $xp->{'channel'}->{'item'};

printf("Items to process: %s\n",$#$itemsp);

download_attachments();

convert_items();

print Dumper(\%Attachments);

sub download_attachments {
    for (my $i = 0; $i < $#$itemsp; $i++) {
	my $item = $$itemsp[$i];
	if ($item->{'wp:post_type'} eq 'attachment') {
	    my $url = $item->{'wp:attachment_url'} || '';
	    $Attachments{$url} = basename{$url};
	    my $filename = $uploaddir.'/'.basename($url);
	    get_file($url,$filename);
	}
    }
}

sub convert_items {
    for (my $i = 0; $i < $#$itemsp; $i++) {
	my $item = $$itemsp[$i];
	my $fn = $importdir.'/'.make_file_name($item->{'title'},
					       $item->{'wp:post_type'});
	printf("Saving %s to %s\n",$item->{'title'},$fn);
	
	open WIKIPAGE, ">", $fn or die "Could not open wikipage $fn: $!";
	print WIKIPAGE "(:title ".$item->{'title'}.":)\n";
	print WIKIPAGE "(:creator: ".$item->{'dc:creator'}.":)\n";
	print WIKIPAGE "(:pubdate: ".$item->{'pubDate'}.":)\n";
	print WIKIPAGE "(:link: ".$item->{'link'}.":)\n";
	if ($item->{'wp:post_type'} eq 'attachment') {
	    print WIKIPAGE "Remote Attachment URL: ".$item->{'wp:attachment_url'}."\n";
	} else {
	    my $content = convert_content($item->{'content:encoded'});
	    $content = fixup_attachments($content);
	    print WIKIPAGE $content;
	}
	close(WIKIPAGE);
    }
}

sub make_file_name {
    my $t = shift @_;
    my $type = shift @_;
    $type =~ s/(\w)(\w*)/\U$1\L$2/;
    $t =~ s/[^[:alnum:][:space:]]//g;
    $t =~ s/(\w)(\w*)/\U$1\L$2/g;
    $t =~ s/\s*//g;
    $t = "${type}.${t}.txt";
    return $t;
}

sub get_file {
    my ($url,$location) = @_;
    print "Getting $url, saving to $location\n";
    my $response = $ua->get($url);
    if ($response->is_success) {
	open  LOCATION, ">$location" or die "can't open $location: $!";
	print LOCATION $response->decoded_content;
	close LOCATION;
    }
    else {
	warn $response->status_line;
    }
}

sub convert_content {
    my $content = shift @_;
    my ($tempfh, $tempfn) = tempfile(UNLINK=>1);
    print $tempfh $content;
    my $filtered_content = `/usr/bin/markdown $tempfn`;
    return $wc->html2wiki( html=> $filtered_content );
}

sub fixup_attachments {
    my $content = shift @_;
    # stub
    return $content;
}
