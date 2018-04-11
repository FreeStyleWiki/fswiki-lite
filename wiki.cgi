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
		print "<li><a href=\"".&Wiki::create_page_url($page->{NAME})."\">".
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
	
	unless(&Wiki::page_exists($in{"p"})){
		undef %in;
		$in{"a"} = "edit";
		require $EDIT_SCRIPT;
		return;
	}
	
	my $source = &Wiki::get_page($in{"p"});
	my $html   = &Wiki::process_wiki($source,1);
	
	&print_header($in{"p"},1);
	
	if(&Wiki::page_exists("Header")){
		print "<div class=\"header\">\n";
		print &Wiki::process_wiki(&Wiki::get_page("Header"));
		print "</div>\n";
	}

	print "<div class=\"day body section\">\n";
	print $html;
	print "</div>\n";
	
	if(&Wiki::page_exists("Footer")){
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
	print &Wiki::Plugin::search();
	
	my $buf          = "";
	my $or_search    = $in{'t'} eq 'or';
	my $with_content = $in{'c'} eq 'true';
	my $word = &Util::trim($in{'w'});
	
	my $ignore_case = 1;
	my $conv_upper_case = ($ignore_case and $word =~ /[A-Za-z]/);
	
	$word = uc $word if ($conv_upper_case);
	my @words = grep { $_ ne '' } split(/ +|��+/, $word);
	if (@words) {
	#---------------------------------------------------------------------------
	# �����¹�
	my @list = &Wiki::get_page_list();
	my $res = '';
	PAGE:
	foreach my $page (@list){
		my $name = $page->{NAME};
		# �ڡ���̾�⸡���оݤˤ���
		my $page = $name;
		$page .= "\n".&Wiki::get_page($name) if ($with_content);
		my $pageref = ($conv_upper_case) ? \(my $page2 = uc $page) : \$page;
		my $index;

		if ($or_search) {
			# OR���� -------------------------------------------------------
			WORD:
			foreach(@words){
				next WORD if (($index = index $$pageref, $_) == -1);
				$res .= "<li>".
					    "<a href=\"".&Wiki::create_page_url($name)."\">".&Util::escapeHTML($name)."</a>".
						" - ".
						&Util::escapeHTML(&get_match_content($page, $index)).
						"</li>\n";
				next PAGE;
			}
		} else {
			# AND���� ------------------------------------------------------
			WORD:
			foreach(@words){
				next PAGE if (($index = index $$pageref, $_) == -1);
			}
			$res .= "<li>".
					"<a href=\"".&Wiki::create_page_url($name)."\">".Util::escapeHTML($name)."</a>".
					" - ".
					Util::escapeHTML(&get_match_content($page, $index)).
					"</li>\n";
		}
	}
	print "$buf<ul>\n$res</ul>\n" if ($res ne '');
	}
	
	&print_footer();
}

#-------------------------------------------------------------------------------
# �����˥ޥå������Ԥ���Ф��ؿ�
#-------------------------------------------------------------------------------
sub get_match_content {
	my $content = shift;
	my $index   = shift;

	# �����˥ޥå������Ԥ���Ƭʸ���ΰ��֤���롣
	# ��$content �� $index ���ܤ�ʸ��������Ƭ�����˲���ʸ����õ����
	# ��$index �ΰ��֤�ޤ�Ԥ���Ƭʸ���ΰ��֤ϲ���ʸ���μ��ʤΤ� +1 ���롣
	# ����Ƭ�����˲���ʸ����̵���ä���ǽ�ιԤʤΤǡ���̤� 0(��Ƭ)��
	#   (���Ĥ���ʤ��� rindex() = -1 �ˤʤ�Τǡ�+1 ���Ƥ��礦�� 0)
	my $pre_index = rindex($content, "\n", $index) + 1;

	# �����˥ޥå������Ԥ�����ʸ���ΰ��֤���롣
	# ��$content �� $index ���ܤ�ʸ���������������˲���ʸ����õ����
	my $post_index = index($content, "\n", $index);

	# ���������˲���ʸ�����ʤ��ä���ǽ��ԤʤΤ� $pre_index �ʹ����Ƥ��ֵѡ�
	return substr($content, $pre_index) if ($post_index == -1);

	# ���Ĥ��ä�����ʸ���˶��ޤ줿ʸ������ֵѡ�
	return substr($content, $pre_index, $post_index - $pre_index);
}

