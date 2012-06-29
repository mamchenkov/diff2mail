#!/usr/bin/perl -w

use strict;
use LWP::Simple;
use File::Temp qw/ :POSIX/;
use Text::Diff;
use MIME::Lite;

my %mail = (
	'From' => 'root@localhost',
	'To' => 'root@localhost',
	'Type' => 'multipart/alternative',
);

my @urls = (
	{
		'name' => 'some script',
		'old' => 'http://local.../file.js',
		'new' => 'http://remote../file.js',
	},
);

foreach my $pair (@urls) {
	
	my $old_file = fetch_temp_file($pair->{'old'});
	my $new_file = fetch_temp_file($pair->{'new'});
	if ($old_file && $new_file) {
		my $diff_text = diff($old_file, $new_file);
		my $diff_html = diff($old_file, $new_file, {'STYLE' => 'Text::Diff::HTML'});
		# Skip sending emails if no changes found
		if (!$diff_html) {
			next;
		}

		$diff_text =~ s/${old_file}/$pair->{'old'}/g;
		$diff_text =~ s/${new_file}/$pair->{'new'}/g;

		$diff_html =~ s/${old_file}/$pair->{'old'}/g;
		$diff_html =~ s/${new_file}/$pair->{'new'}/g;

		my $css = '
			<style>
			.file span { display: block; }
			.file .fileheader, .file .hunkheader {color: #888; display: block;}
			.file .hunk .ctx { background: #eee; display: block;}
			.file .hunk ins { background: #dfd; text-decoration: none; display: block; }
			.file .hunk del { background: #fdd; text-decoration: none; display: block; }
			</style>
			';
		$diff_html = $css . '<code><pre>' . $diff_html . '</pre></code>';

		$mail{'Subject'} = 'Changes in ' . $pair->{'name'};

		my $msg = MIME::Lite->new(%mail);
		$msg->attach('Type' => 'text/plain', 'Data' => $diff_text);
		$msg->attach('Type' => 'text/html', 'Data' => $diff_html);
		$msg->send();
	}
	unlink($old_file);
	unlink($new_file);
}

# Fetch remote URL and save it in local temporary file.
sub fetch_temp_file{
	my $url = shift;
	my $result;

	my $temp_file = tmpnam();
	if (is_success(getstore($url, $temp_file))) {
		dos_to_unix($temp_file);
		$result = $temp_file;
	}

	return $result;
}

# Convert file from DOS to Unix end-of-line's.
# This should minimize the diff to the important stuff only.
sub dos_to_unix {
	my $file = shift;

	my $file_bak = $file . ".bak";
	rename($file, $file_bak);
	open INPUT, "<$file_bak";
	open OUTPUT, ">$file";
	while (<INPUT>) {
		s/\r\n$/\n/; # Convert CR LF to LF
		print OUTPUT $_;
	}
	close INPUT;
	close OUTPUT;
	unlink($file_bak);
}
