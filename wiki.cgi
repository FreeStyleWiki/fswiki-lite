#!/usr/bin/perl
################################################################################
#
# FSWiki Lite
#
################################################################################
require "./lib/common.pl";
#===============================================================================
# �����ο���ʬ��
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
# �ڡ����ΰ���
#-------------------------------------------------------------------------------
sub list_page {
	my @pages = &Wiki::get_page_list();
	
	&print_header("����");
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
# �ڡ�����ɽ��
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
# �ڡ����θ���
#-------------------------------------------------------------------------------
sub search_page {
	
	&print_header("����");
	print "<form action=\"$MAIN_SCRIPT\" method=\"GET\">\n";
	print "  ������� <input type=\"text\" name=\"w\" size=\"20\" value=\"".&Util::escapeHTML($in{'w'})."\">\n";
	print "  <input type=\"submit\" value=\" �� �� \">\n";
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
			print "<li>��������ڡ�����¸�ߤ��ޤ���</li>\n";
		}
		print "</ul>\n";
	}
	
	&print_footer();
}

