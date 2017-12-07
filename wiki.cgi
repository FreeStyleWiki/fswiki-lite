#!/usr/bin/perl
################################################################################
#
# FSWiki Lite
#
################################################################################
require "./lib/common.pl";
#===============================================================================
# 処理の振り分け
#===============================================================================
&ReadParse();
if($in{"p"} eq ""){
	$in{"p"} = "FrontPage";
}

if($in{"a"} eq "list"){
	&list_page();
	
} elsif($in{"a"} eq "search"){
	&search_page();
	
} else {
	&show_page();
	
}

#-------------------------------------------------------------------------------
# ページの一覧
#-------------------------------------------------------------------------------
sub list_page {
	my @pages = &Wiki::get_page_list();
	
	&print_header("一覧");
	print "<ul>\n";
	foreach my $page (@pages){
		print "<li><a href=\"$MAIN_SCRIPT?p=".&Util::url_encode($page->{NAME})."\">".
		      &Util::escapeHTML($page->{NAME})."</a>".
		      " - ".&Util::format_date($page->{TIME})."</li>\n";
	}
	print "</ul>\n";
	&print_footer();
}

#-------------------------------------------------------------------------------
# ページを表示
#-------------------------------------------------------------------------------
sub show_page {
	
	unless(&Wiki::exists_page($in{"p"})){
		undef %in;
		$in{"a"} = "edit";
		require $EDIT_SCRIPT;
		return;
	}
	
	my $source = &Wiki::get_page($in{"p"});
	my $html   = &Wiki::process_wiki($source,1);
	
	&print_header($in{"p"},1);
	
	if(&Wiki::exists_page("Header")){
		print "<div class=\"header\">\n";
		print &Wiki::process_wiki(&Wiki::get_page("Header"));
		print "</div>\n";
	}

	print "<div class=\"day body section\">\n";
	print $html;
	print "</div>\n";
	
	if(&Wiki::exists_page("Footer")){
		print "<div class=\"comment\">\n";
		print &Wiki::process_wiki(&Wiki::get_page("Footer"));
		print "</div>\n";
	}
	
	&print_footer();
}

#-------------------------------------------------------------------------------
# ページの検索
#-------------------------------------------------------------------------------
sub search_page {
	
	&print_header("検索");
	print "<form action=\"$MAIN_SCRIPT\" method=\"GET\">\n";
	print "  キーワード <input type=\"text\" name=\"w\" size=\"20\" value=\"".&Util::escapeHTML($in{'w'})."\">\n";
	print "  <input type=\"submit\" value=\" 検 索 \">\n";
	print "  <input type=\"hidden\" name=\"a\" value=\"search\">\n";
	print "</form>\n";
	
	if($in{'w'} ne ""){
		my @pages = &Wiki::get_page_list();
		my $find  = 0;
		print "<ul>\n";
		foreach my $page (@pages){
			my $source = $page->{NAME}."\n".&Wiki::get_page($page->{NAME});
			if(index($source,$in{'w'})!=-1){
				print "  <li><a href=\"$MAIN_SCRIPT?p=".&Util::url_encode($page->{NAME})."\">".&Util::escapeHTML($page->{NAME})."</a></li>\n";
				$find = 1;
			}
		}
		if($find==0){
			print "<li>該当するページは存在しません。</li>\n";
		}
		print "</ul>\n";
	}
	
	&print_footer();
}

