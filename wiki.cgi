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
		print "<li><a href=\"".&Wiki::create_page_url($page->{NAME})."\">".
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
# ページの検索
#-------------------------------------------------------------------------------
sub search_page {
	
	&print_header("検索");
	print &Wiki::Plugin::search();
	
	my $buf          = "";
	my $or_search    = $in{'t'} eq 'or';
	my $with_content = $in{'c'} eq 'true';
	my $word = &Util::trim($in{'w'});
	
	my $ignore_case = 1;
	my $conv_upper_case = ($ignore_case and $word =~ /[A-Za-z]/);
	
	$word = uc $word if ($conv_upper_case);
	my @words = grep { $_ ne '' } split(/ +|　+/, $word);
	if (@words) {
	#---------------------------------------------------------------------------
	# 検索実行
	my @list = &Wiki::get_page_list();
	my $res = '';
	PAGE:
	foreach my $page (@list){
		my $name = $page->{NAME};
		# ページ名も検索対象にする
		my $page = $name;
		$page .= "\n".&Wiki::get_page($name) if ($with_content);
		my $pageref = ($conv_upper_case) ? \(my $page2 = uc $page) : \$page;
		my $index;

		if ($or_search) {
			# OR検索 -------------------------------------------------------
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
			# AND検索 ------------------------------------------------------
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
# 検索にマッチした行を取り出す関数
#-------------------------------------------------------------------------------
sub get_match_content {
	my $content = shift;
	my $index   = shift;

	# 検索にマッチした行の先頭文字の位置を求める。
	# ・$content の $index 番目の文字から先頭方向に改行文字を探す。
	# ・$index の位置を含む行の先頭文字の位置は改行文字の次なので +1 する。
	# ・先頭方向に改行文字が無かったら最初の行なので、結果は 0(先頭)。
	#   (見つからないと rindex() = -1 になるので、+1 してちょうど 0)
	my $pre_index = rindex($content, "\n", $index) + 1;

	# 検索にマッチした行の末尾文字の位置を求める。
	# ・$content の $index 番目の文字から末尾方向に改行文字を探す。
	my $post_index = index($content, "\n", $index);

	# 末尾方向に改行文字がなかったら最終行なので $pre_index 以降全てを返却。
	return substr($content, $pre_index) if ($post_index == -1);

	# 見つかった改行文字に挟まれた文字列を返却。
	return substr($content, $pre_index, $post_index - $pre_index);
}

