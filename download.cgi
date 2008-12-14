#!/usr/bin/perl
################################################################################
#
# FSWiki Lite - 添付ファイルをダウンロードするためのCGIスクリプト
#
################################################################################
require "./lib/common.pl";
#==============================================================================
# パラメータを受け取る
#==============================================================================
&ReadParse();
my $page = $in{"p"};
my $file = $in{"f"};

#==============================================================================
# エラーチェック
#==============================================================================
if($page eq ""){
	&Util::error("ページが指定されていません。");
}
if($file eq ""){
	&Util::error("ファイルが指定されていません。");
}
#==============================================================================
# ダウンロード
#==============================================================================
my $filename = sprintf("$main::ATTACH_DIR/%s.%s",&Util::url_encode($page),&Util::url_encode($file));
unless(-e $filename){
	&Util::error("指定されたファイルは存在しません。");
}

my $contenttype = &get_mime_type($file);
my $ua = $ENV{"HTTP_USER_AGENT"};
my $disposition = ($contenttype =~ /^image\// && $ua !~ /MSIE/ ? "inline" : "attachment");

&jcode::convert(\$file,'sjis');

print "Content-Type: $contenttype\n";
print "Content-Disposition: $disposition;filename=\"$file\"\n\n";
open(DATA,$filename);
binmode(DATA);
while(<DATA>){
	print $_;
}
close(DATA);


#==============================================================================
# MIMEタイプを取得します
#==============================================================================
sub get_mime_type {
	my $file  = shift;
	my $type  = lc(substr($file,rindex($file,".")));
	my $ctype;
	
	if   ($type eq ".gif" ){ $ctype = "image/gif"; }
	elsif($type eq ".txt" ){ $ctype = "text/plain"; }
	elsif($type eq ".rb"  ){ $ctype = "text/plain"; }
	elsif($type eq ".pl"  ){ $ctype = "text/plain"; }
	elsif($type eq ".java"){ $ctype = "text/plain"; }
#	elsif($type eq ".html"){ $ctype = "text/html"; }
#	elsif($type eq ".htm" ){ $ctype = "text/html"; }
	elsif($type eq ".css" ){ $ctype = "text/css"; }
	elsif($type eq ".jpeg"){ $ctype = "image/jpeg"; }
	elsif($type eq ".jpg" ){ $ctype = "image/jpeg"; }
	elsif($type eq ".png" ){ $ctype = "image/png"; }
	elsif($type eq ".bmp" ){ $ctype = "image/bmp"; }
	elsif($type eq ".doc" ){ $ctype = "application/msword"; }
	elsif($type eq ".xls" ){ $ctype = "application/vnd.ms-excel"; }
	else                   { $ctype = "application/octet-stream"; }
	
	return $ctype;
}
