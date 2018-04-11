#!/usr/bin/perl
################################################################################
#
# FSWiki Lite - ページ作成、編集用スクリプト
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

if(!&Util::check_pagename($in{"p"})){
	&Util::error("ページ名に使用できない文字が含まれています。");
}

if($in{"a"} eq "edit"){
	&edit_page();

} elsif($in{"a"} eq "new"){
	&new_page();
	
} elsif($in{"a"} eq "save"){
	&save_page();
	
} elsif($in{"a"} eq "attach"){
	&attach_file();
	
} elsif($in{"a"} eq "delconf"){
	&attach_delete_confirm();
	
} elsif($in{"a"} eq "delete"){
	&attach_delete();
	
} else {
	&Wiki::redirect("FrontPage");
}

#-------------------------------------------------------------------------------
# ページの編集
#-------------------------------------------------------------------------------
sub edit_page {
	my $source  = shift;
	my $page    = $in{"p"};
	my $preview = 0;
	my $time    = $in{"t"};
	
	if($source ne ""){
		$preview = 1;
	} elsif(&Wiki::page_exists($page)){
		$source = &Wiki::get_page($page);
		$time   = &Wiki::get_last_modified($page);
	}
	
	&print_header($in{"p"}."の編集");
	
	if($preview==1){
		print &Wiki::process_wiki($source);
	}
	
	print "<form action=\"$EDIT_SCRIPT\" method=\"POST\">\n";
	print "  <textarea name=\"source\" rows=\"20\" cols=\"80\">".&Util::escapeHTML($source)."</textarea><br>\n";
	print "  <input type=\"submit\" name=\"do_save\" value=\" 保 存 \">\n";
	print "  <input type=\"submit\" name=\"preview\" value=\"プレビュー\">\n";
	print "  <input type=\"hidden\" name=\"a\" value=\"save\">\n";
	print "  <input type=\"hidden\" name=\"p\" value=\"".&Util::escapeHTML($page)."\">\n";
	print "  <input type=\"hidden\" name=\"t\" value=\"".&Util::escapeHTML($time)."\">\n";
	print "</form>\n";
	
	opendir(DIR, $main::ATTACH_DIR);
	my ($attachentry, @attachfiles);
	while($attachentry = readdir(DIR)){
		my $type = rindex($attachentry,&Util::url_encode($page).".");
		if($type eq 0){
			push(@attachfiles, "$main::ATTACH_DIR/$attachentry");
		}
	}
	closedir(DIR);
	foreach my $attach (@attachfiles){
		$attach =~ /^\Q$main::ATTACH_DIR\E\/(.+)\.(.+)$/;
		my $pagename = &Util::url_decode($1);
		my $filename = &Util::url_decode($2);
		print &Wiki::Plugin::ref($filename);
		printf("[<a href=\"%s\">削除</a>]\n",&Wiki::create_url({a=>delconf,p=>$pagename,f=>$filename}));
	}
	
	print "<form action=\"$EDIT_SCRIPT\" method=\"post\" enctype=\"multipart/form-data\">\n";
	print "  <input type=\"file\" name=\"f\">\n";
	print "  <input type=\"submit\" name=\"do_attach\" value=\" 添 付 \">\n";
	print "  <input type=\"hidden\" name=\"a\" value=\"attach\">\n";
	print "  <input type=\"hidden\" name=\"p\" value=\"".&Util::escapeHTML($page)."\">\n";
	print "</form>\n";
	
	&print_footer();
}

#-------------------------------------------------------------------------------
# ページの作成
#-------------------------------------------------------------------------------
sub new_page {
	&print_header("ページの作成");
	print "<form action=\"$EDIT_SCRIPT\" method=\"POST\">\n";
	print "  <input type=\"text\" name=\"p\" size=\"40\">\n";
	print "  <input type=\"submit\" name=\"do_save\" value=\" 作 成 \">\n";
	print "  <input type=\"hidden\" name=\"a\" value=\"edit\">\n";
	print "</form>\n";
	&print_footer();
}

#-------------------------------------------------------------------------------
# ページの保存
#-------------------------------------------------------------------------------
sub save_page {
	my $page   = $in{"p"};
	my $source = $in{"source"};
	
	if($in{"preview"} ne ""){
		&edit_page($source);
		
	} else {
		# ページの削除
		if($source eq ""){
			# 更新の重複チェック
			if(&Wiki::page_exists($page)){
				if($in{"t"} != &Wiki::get_last_modified($page)){
					&Util::error("このページは既に更新されています。");
				} else {
					&Wiki::remove_page($page);
				}
			}
			&Wiki::redirect("FrontPage");
			
		# ページの作成または更新
		} else {
			# 更新の重複チェック
			if(&Wiki::page_exists($page)){
				if($in{"t"} != &Wiki::get_last_modified($page)){
					&Util::error("このページは既に更新されています。");
				}
			}
			&Wiki::save_page($page,$source);
			&Wiki::redirect($page);
		}
	}
}

#-------------------------------------------------------------------------------
# ファイルの添付
#-------------------------------------------------------------------------------
sub attach_file {
	my $page = $in{"p"};
	my $file = $in{"f"};    # ファイル内容を取得
	my $name = $incfn{"f"}; # ファイル名を取得
	
	if($file eq ""){
		&Util::error("ファイルが指定されていません。");
	}
	
	if($name eq ""){
		return;
	}
	
	$name =~ s/\\/\//g;                        # パス区切り文字を/に変換
	$name = substr($name,rindex($name,"/")+1); # ファイル名のみを取得
	
	my $filename = sprintf("%s/%s.%s",$main::ATTACH_DIR,&Util::url_encode($page),&Util::url_encode($name));
	open(DATA,">$filename");
	binmode(DATA);
	print DATA $file;
	close(DATA);
	
	&Wiki::redirectURL(&Wiki::create_url({a=>edit,p=>$page}));
}

#-------------------------------------------------------------------------------
# 添付ファイルの削除確認
#-------------------------------------------------------------------------------
sub attach_delete_confirm {
	my $page = $in{"p"};
	my $file = $in{"f"};
	
	if($file eq ""){
		&Util::error("ファイルが指定されていません。");
	}
	
	&print_header("添付ファイルの削除");
	printf ("<p><a href=\"%s\">%s</a>から".
			"<a href=\"%s\">%s</a>を削除してよろしいですか？</p>\n",
			&Wiki::create_url({p=>$page}),&Util::escapeHTML($page),
			&Wiki::create_url({p=>$page,f=>$file},$main::DOWNLOAD_SCRIPT),&Util::escapeHTML($file));
	
	print "<form action=\"$EDIT_SCRIPT\" method=\"POST\">\n";
	print "  <input type=\"submit\" name=\"do_delete\" value=\" 削 除 \">\n";
	print "  <input type=\"hidden\" name=\"p\" value=\"".&Util::escapeHTML($page)."\">\n";
	print "  <input type=\"hidden\" name=\"f\" value=\"".&Util::escapeHTML($file)."\">\n";
	print "  <input type=\"hidden\" name=\"a\" value=\"delete\">\n";
	print "</form>\n";
	&print_footer();
}

#-------------------------------------------------------------------------------
# 添付ファイルの削除
#-------------------------------------------------------------------------------
sub attach_delete {
	my $page = $in{"p"};
	my $file = $in{"f"};
	
	if($file eq ""){
		&Util::error("ファイルが指定されていません。");
	}
	
	my $filename = sprintf("$ATTACH_DIR/%s.%s",&Util::url_encode($page),&Util::url_encode($file));
	unlink($filename);
	
	&Wiki::redirectURL(&Wiki::create_url({a=>edit,p=>$page}));
}
