#!/usr/bin/perl
################################################################################
#
# FSWiki Lite - �ڡ����������Խ��ѥ�����ץ�
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

if(!&Util::check_pagename($in{"p"})){
	&Util::error("�ڡ���̾�˻��ѤǤ��ʤ�ʸ�����ޤޤ�Ƥ��ޤ���");
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
# �ڡ������Խ�
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
	
	&print_header($in{"p"}."���Խ�");
	
	if($preview==1){
		print &Wiki::process_wiki($source);
	}
	
	print "<form action=\"$EDIT_SCRIPT\" method=\"POST\">\n";
	print "  <textarea name=\"source\" rows=\"20\" cols=\"80\">".&Util::escapeHTML($source)."</textarea><br>\n";
	print "  <input type=\"submit\" name=\"do_save\" value=\" �� ¸ \">\n";
	print "  <input type=\"submit\" name=\"preview\" value=\"�ץ�ӥ塼\">\n";
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
		printf("[<a href=\"%s\">���</a>]\n",&Wiki::create_url({a=>delconf,p=>$pagename,f=>$filename}));
	}
	
	print "<form action=\"$EDIT_SCRIPT\" method=\"post\" enctype=\"multipart/form-data\">\n";
	print "  <input type=\"file\" name=\"f\">\n";
	print "  <input type=\"submit\" name=\"do_attach\" value=\" ź �� \">\n";
	print "  <input type=\"hidden\" name=\"a\" value=\"attach\">\n";
	print "  <input type=\"hidden\" name=\"p\" value=\"".&Util::escapeHTML($page)."\">\n";
	print "</form>\n";
	
	&print_footer();
}

#-------------------------------------------------------------------------------
# �ڡ����κ���
#-------------------------------------------------------------------------------
sub new_page {
	&print_header("�ڡ����κ���");
	print "<form action=\"$EDIT_SCRIPT\" method=\"POST\">\n";
	print "  <input type=\"text\" name=\"p\" size=\"40\">\n";
	print "  <input type=\"submit\" name=\"do_save\" value=\" �� �� \">\n";
	print "  <input type=\"hidden\" name=\"a\" value=\"edit\">\n";
	print "</form>\n";
	&print_footer();
}

#-------------------------------------------------------------------------------
# �ڡ�������¸
#-------------------------------------------------------------------------------
sub save_page {
	my $page   = $in{"p"};
	my $source = $in{"source"};
	
	if($in{"preview"} ne ""){
		&edit_page($source);
		
	} else {
		# �ڡ����κ��
		if($source eq ""){
			# �����ν�ʣ�����å�
			if(&Wiki::page_exists($page)){
				if($in{"t"} != &Wiki::get_last_modified($page)){
					&Util::error("���Υڡ����ϴ��˹�������Ƥ��ޤ���");
				} else {
					&Wiki::remove_page($page);
				}
			}
			&Wiki::redirect("FrontPage");
			
		# �ڡ����κ����ޤ��Ϲ���
		} else {
			# �����ν�ʣ�����å�
			if(&Wiki::page_exists($page)){
				if($in{"t"} != &Wiki::get_last_modified($page)){
					&Util::error("���Υڡ����ϴ��˹�������Ƥ��ޤ���");
				}
			}
			&Wiki::save_page($page,$source);
			&Wiki::redirect($page);
		}
	}
}

#-------------------------------------------------------------------------------
# �ե������ź��
#-------------------------------------------------------------------------------
sub attach_file {
	my $page = $in{"p"};
	my $file = $in{"f"};    # �ե��������Ƥ����
	my $name = $incfn{"f"}; # �ե�����̾�����
	
	if($file eq ""){
		&Util::error("�ե����뤬���ꤵ��Ƥ��ޤ���");
	}
	
	if($name eq ""){
		return;
	}
	
	$name =~ s/\\/\//g;                        # �ѥ����ڤ�ʸ����/���Ѵ�
	$name = substr($name,rindex($name,"/")+1); # �ե�����̾�Τߤ����
	
	my $filename = sprintf("%s/%s.%s",$main::ATTACH_DIR,&Util::url_encode($page),&Util::url_encode($name));
	open(DATA,">$filename");
	binmode(DATA);
	print DATA $file;
	close(DATA);
	
	&Wiki::redirectURL(&Wiki::create_url({a=>edit,p=>$page}));
}

#-------------------------------------------------------------------------------
# ź�եե�����κ����ǧ
#-------------------------------------------------------------------------------
sub attach_delete_confirm {
	my $page = $in{"p"};
	my $file = $in{"f"};
	
	if($file eq ""){
		&Util::error("�ե����뤬���ꤵ��Ƥ��ޤ���");
	}
	
	&print_header("ź�եե�����κ��");
	printf ("<p><a href=\"%s\">%s</a>����".
			"<a href=\"%s\">%s</a>�������Ƥ�����Ǥ�����</p>\n",
			&Wiki::create_url({p=>$page}),&Util::escapeHTML($page),
			&Wiki::create_url({p=>$page,f=>$file},$main::DOWNLOAD_SCRIPT),&Util::escapeHTML($file));
	
	print "<form action=\"$EDIT_SCRIPT\" method=\"POST\">\n";
	print "  <input type=\"submit\" name=\"do_delete\" value=\" �� �� \">\n";
	print "  <input type=\"hidden\" name=\"p\" value=\"".&Util::escapeHTML($page)."\">\n";
	print "  <input type=\"hidden\" name=\"f\" value=\"".&Util::escapeHTML($file)."\">\n";
	print "  <input type=\"hidden\" name=\"a\" value=\"delete\">\n";
	print "</form>\n";
	&print_footer();
}

#-------------------------------------------------------------------------------
# ź�եե�����κ��
#-------------------------------------------------------------------------------
sub attach_delete {
	my $page = $in{"p"};
	my $file = $in{"f"};
	
	if($file eq ""){
		&Util::error("�ե����뤬���ꤵ��Ƥ��ޤ���");
	}
	
	my $filename = sprintf("$ATTACH_DIR/%s.%s",&Util::url_encode($page),&Util::url_encode($file));
	unlink($filename);
	
	&Wiki::redirectURL(&Wiki::create_url({a=>edit,p=>$page}));
}
