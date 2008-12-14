################################################################################
#
# FSWikiLite ���̴ؿ��ե�����
#
################################################################################
require "./lib/cgi-lib.pl";
require "./lib/jcode.pl";
require "./lib/mimew.pl";
require "./lib/setup.pl";
#-------------------------------------------------------------------------------
# �������Ϥ����ڡ���������
#-------------------------------------------------------------------------------
sub redirect {
	my $page = shift;
	my $url  = "$MAIN_SCRIPT?p=".&Util::url_encode($page);
	&redirectURL($url);
}

#-------------------------------------------------------------------------------
# �������Ϥ���URL������
#-------------------------------------------------------------------------------
sub redirectURL {
	my $url  = shift;
	
	print "Content-Type: text/html;charset=EUC-JP\n";
	print "Pragma: no-cache\n";
	print "Cache-Control: no-cache\n\n";
	print "<html>\n";
	print "  <head>\n";
	print "    <title>moving...</title>\n";
	print "    <meta http-equiv=\"Refresh\" content=\"0;URL=$url\">\n";
	print "  </head>\n";
	print "  <body>\n";
	print "    Wait or <a href=\"$url\">Click Here!!</a>\n";
	print "  </body>\n";
	print "</html>\n";
	
	exit;
}

#-------------------------------------------------------------------------------
# �إå���ɽ��
#-------------------------------------------------------------------------------
sub print_header {
	my $title = shift;
	my $show  = shift;
	
	print "Content-Type: text/html;charset=EUC-JP\n";
	print "Pragma: no-cache\n";
	print "Cache-Control: no-cache\n\n";
	print "<html>\n";
	print "<head>\n";
	print "<title>".&Util::escapeHTML($title)." - $SITE_TITLE</title>\n";
	print "<link rel=\"stylesheet\" type=\"text/css\" href=\"$THEME_URL\">\n";
	print "</head>\n";
	print "<body>\n";
	
	print "<div class=\"adminmenu\">\n";
	print "  <span class=\"adminmenu\">\n";
	print "    <a href=\"$MAIN_SCRIPT?p=FrontPage\">FrontPage</a>\n";
	print "    <a href=\"$EDIT_SCRIPT?a=new\">����</a>\n";
	if($show==1){
		print "    <a href=\"$EDIT_SCRIPT?a=edit&p=".&Util::url_encode($in{"p"})."\">�Խ�</a>\n";
	}
	print "    <a href=\"$MAIN_SCRIPT?a=search\">����</a>\n";
	print "    <a href=\"$MAIN_SCRIPT?a=list\">����</a>\n";
	print "    <a href=\"$MAIN_SCRIPT?p=Help\">�إ��</a>\n";
	print "  </span>\n";
	print "</div>\n";
	
	print "<h1>".&Util::escapeHTML($title)."</h1>\n";
	if(&Wiki::exists_page("Menu")){
		print "<div class=\"main\">\n";
	}
	
}

#-------------------------------------------------------------------------------
# �եå���ɽ��
#-------------------------------------------------------------------------------
sub print_footer {
	if(&Wiki::exists_page("Menu")){
		print "</div>\n";
		print "<div class=\"sidebar\">\n";
		print &Wiki::process_wiki(&Wiki::get_page("Menu"));
		print "</div>\n";
	}
	print "<div class=\"footer\">Powered by <a href=\"$main::SITE_URL\">FreeStyleWikiLite $main::VERSION</a></div>\n";
	print "</body></html>\n";
}

###############################################################################
#
# Wiki��Ϣ�δؿ����󶡤���ѥå�����
#
###############################################################################
package Wiki;
#-------------------------------------------------------------------------------
# �ڡ��������
#-------------------------------------------------------------------------------
sub get_page {
	my $page = &Util::url_encode(shift);
	
	open(DATA,"$main::DATA_DIR/$page.wiki") or &Util::error("$main::DATA_DIR/$page.wiki�Υ����ץ�˼��Ԥ��ޤ�����");
	my $content = "";
	while(<DATA>){
		$content .= $_;
	}
	close(DATA);
	
	return $content;
}
#-------------------------------------------------------------------------------
# �ڡ�������¸
#-------------------------------------------------------------------------------
sub save_page {
	my $page   = shift;
	my $source = shift;
	
	$page = &Util::trim($page);
	$source =~ s/\r\n/\n/g;
	$source =~ s/\r/\n/g;
	
	my $enc_page = &Util::url_encode($page);
	my $action   = 'MODIFY';
	unless(-e "$main::DATA_DIR/$enc_page.wiki"){
		$action = 'CREATE';
	}
	
	# �Хå����åץե���������
	if(-e "$main::DATA_DIR/$enc_page.wiki"){
		open(BACKUP,">$main::BACKUP_DIR/$enc_page.bak") or &Util::error("$main::BACKUP_DIR/$enc_page.bak�Υ����ץ�˼��Ԥ��ޤ�����");
		open(DATA  ,"$main::DATA_DIR/$enc_page.wiki")   or &Util::error("$main::DATA_DIR/$enc_page.wiki�Υ����ץ�˼��Ԥ��ޤ�����");
		while(<DATA>){
			print BACKUP $_;
		}
		close(DATA);
		close(BACKUP);
	}
	
	# �������Ƥ���¸
	open(DATA,">$main::DATA_DIR/$enc_page.wiki") or &Util::error("$main::DATA_DIR/$enc_page.wiki�Υ����ץ�˼��Ԥ��ޤ�����");
	print DATA $source;
	close(DATA);
	
	&send_mail($action,$page);
}
#-------------------------------------------------------------------------------
# �ڡ�������
#-------------------------------------------------------------------------------
sub remove_page {
	my $page     = shift;
	my $enc_page = &Util::url_encode($page);
	unlink("$main::DATA_DIR/$enc_page.wiki") or &Util::error("$main::DATA_DIR/$enc_page.wiki�κ���˼��Ԥ��ޤ�����");
	
	&send_mail('DELETE',$page);
}
#-------------------------------------------------------------------------------
# �᡼������
#-------------------------------------------------------------------------------
sub send_mail {
	my $action   = shift;
	my $page     = shift;
	my $enc_page = &Util::url_encode($page);
	
	if($main::ADMIN_MAIL eq "" || $main::SEND_MAIL eq ""){
		return;
	}
	
	my $subject = "";
	if($action eq 'CREATE'){
		$subject = "[FSWikiLite]$page����������ޤ���";
		
	} elsif($action eq 'MODIFY'){
		$subject = "[FSWikiLite]$page����������ޤ���";
		
	} elsif($action eq 'DELETE'){
		$subject = "[FSWikiLite]$page���������ޤ���";
	}
	
	# MIME���󥳡���
	$subject = &main::mimeencode($subject);
	
	my $head = "Subject: $subject\n".
	           "From: $main::ADMIN_MAIL\n".
	           "Content-Transfer-Encoding: 7bit\n".
	           "Content-Type: text/plain; charset=\"ISO-2022-JP\"\n".
	           "Reply-To: $main::ADMIN_MAIL\n".
	           "\n";
	
	my $body = "IP:".$ENV{'REMOTE_ADDR'}."\n".
	           "UA:".$ENV{'HTTP_USER_AGENT'}."\n";
	
	if($action eq 'MODIFY' || $action eq 'DELETE'){
		if(-e "$main::BACKUP_DIR/$enc_page.bak"){
			$body .= "�ʲ����ѹ����Υ������Ǥ���\n".
			         "-----------------------------------------------------\n";
			open(BACKUP,"$main::BACKUP_DIR/$enc_page.bak");
			while(my $line = <BACKUP>){
				$body .= $line;
			}
			close(BACKUP);
		}
	}
	
	# ʸ�������ɤ��Ѵ�(jcode.pl����Ѥ���)
	&jcode::convert(\$body,'jis');
	
	open(MAIL,"| $main::SEND_MAIL $main::ADMIN_MAIL");
	print MAIL $head;
	print MAIL $body;
	close(MAIL);
}
#-------------------------------------------------------------------------------
# �ڡ����ΰ��������
#-------------------------------------------------------------------------------
sub get_page_list {
	opendir(DIR, $main::DATA_DIR);
	my ($fileentry, @files);
	while($fileentry = readdir(DIR)){
		my $type = substr($fileentry,rindex($fileentry,"."));
		if($type eq ".wiki"){
			push(@files, "$main::DATA_DIR/$fileentry");
		}
	}
	closedir(DIR);

	my @pages;	
	foreach my $entry (@files){
		my @stat = stat($entry);
		my $time = $stat[9];
		
		$entry = substr($entry,length($main::DATA_DIR)+1);
		$entry =~ /(.+?)\.wiki/;
		my $page = &Util::url_decode($1);
		push(@pages,{NAME=>$page,TIME=>$time});
	}
	
	@pages = sort { $b->{TIME}<=>$a->{TIME} } @pages;
	return @pages;
}

#-------------------------------------------------------------------------------
# �ڡ����ι������������
#-------------------------------------------------------------------------------
sub get_last_modified {
	my $page = shift;
	if(&exists_page($page)){
		my $file = sprintf("%s/%s.wiki",$main::DATA_DIR,&Util::url_encode($page));
		my @stat = stat($file);
		return $stat[9];
	} else {
		return undef;
	}
}

#-------------------------------------------------------------------------------
# �ڡ�����¸�ߤ��뤫�ɤ���
#-------------------------------------------------------------------------------
sub exists_page {
	my $page = &Util::url_encode(shift);
	if(-e "$main::DATA_DIR/$page.wiki"){
		return 1;
	} else {
		return 0;
	}
}

#-------------------------------------------------------------------------------
# Wiki���������Ϥ���HTML��������ޤ�
#-------------------------------------------------------------------------------
sub process_wiki {
	my $source = shift;
	my $main   = shift;
	my $parser = HTMLParser->new($main);
	$parser->parse($source);
	
	return $parser->{html};
}

###############################################################################
#
# HTML�ѡ���
#
###############################################################################
package HTMLParser;
#==============================================================================
# ���󥹥ȥ饯��
#==============================================================================
sub new {
	my $class   = shift;
	my $mainflg = shift;
	my $self    = {};
	
	if(!defined($mainflg) || $mainflg eq ""){ $mainflg = 0; }
	
	$self->{html}  = "";
	$self->{pre}   = "";
	$self->{quote} = "";
	$self->{table} = 0;
	$self->{level} = 0;
	$self->{para}  = 0;
	$self->{p_cnt} = 0;
	$self->{explan} = 0;
	$self->{main}  = $mainflg;
	return bless $self,$class;
}

#===============================================================================
# �ѡ���
#===============================================================================
sub parse {
	my $self   = shift;
	my $source = shift;
	
	$source =~ s/\r//g;
	my @lines = split(/\n/,$source);
	
	foreach my $line (@lines){
		chomp $line;
		
		# ʣ���Ԥ�����
		$self->multi_explanation($line);
		
		my $word1 = substr($line,0,1);
		my $word2 = substr($line,0,2);
		my $word3 = substr($line,0,3);
		
		# ����
		if($line eq ""){
			$self->l_paragraph();
			next;
		}
		
		# �ѥ饰��եץ饰����
		if($line =~ /^{{((.|\s)+?)}}$/){
			my $plugin = &Util::parse_plugin($1);
			my $class  = $main::P_PLUGIN->{$plugin->{command}};
			if(defined($class)){
				$self->l_plugin($plugin);
			} else {
				my @obj = $self->parse_line($line);
				$self->l_text(\@obj);
			}
			next;
		}
		
		# PRE
		if($word1 eq " " || $word1 eq "\t"){
			$self->l_verbatim($line);
			
		# ���Ф�
		} elsif($word3 eq "!!!"){
			my @obj = $self->parse_line(substr($line,3));
			$self->l_headline(1,\@obj);
			
		} elsif($word2 eq "!!"){
			my @obj = $self->parse_line(substr($line,2));
			$self->l_headline(2,\@obj);
			
		} elsif($word1 eq "!"){
			my @obj = $self->parse_line(substr($line,1));
			$self->l_headline(3,\@obj);

		# ����
		} elsif($word3 eq "***"){
			my @obj = $self->parse_line(substr($line,3));
			$self->l_list(3,\@obj);
			
		} elsif($word2 eq "**"){
			my @obj = $self->parse_line(substr($line,2));
			$self->l_list(2,\@obj);
			
		} elsif($word1 eq "*"){
			my @obj = $self->parse_line(substr($line,1));
			$self->l_list(1,\@obj);
			
		# �ֹ��դ�����
		} elsif($word3 eq "+++"){
			my @obj = $self->parse_line(substr($line,3));
			$self->l_numlist(3,\@obj);
			
		} elsif($word2 eq "++"){
			my @obj = $self->parse_line(substr($line,2));
			$self->l_numlist(2,\@obj);
			
		} elsif($word1 eq "+"){
			my @obj = $self->parse_line(substr($line,1));
			$self->l_numlist(1,\@obj);
			
		# ��ʿ��
		} elsif($line eq "----"){
			$self->l_line();
		
		# ����
		} elsif($word2 eq '""'){
			my @obj = $self->parse_line(substr($line,2));
			$self->l_quotation(\@obj);
			
		# ����
		} elsif(index($line,":")==0 && index($line,":",1)!=-1){
			if(index($line,":::")==0){
				$self->{dd} .= substr($line,3);
				next;
			}
			if(index($line,"::")==0){
				if($self->{dt} ne "" || $self->{dd} ne ""){
					$self->multi_explanation;
				}
				$self->{dt} = substr($line,2);
				$self->{dl_flag} = 1;
				next;
			}
			my $dt = substr($line,1,index($line,":",1)-1);
			my $dd = substr($line,index($line,":",1)+1);
			my @obj1 = $self->parse_line($dt);
			my @obj2 = $self->parse_line($dd);
			$self->l_explanation(\@obj1,\@obj2);
			
		# �ơ��֥�
		} elsif($word1 eq ","){
			if($line =~ /,$/){
				$line .= " ";
			}
			my @spl = map {/^"(.*)"$/ ? scalar($_ = $1, s/\"\"/\"/g, $_) : $_}
			              ($line =~ /,\s*(\"[^\"]*(?:\"\"[^\"]*)*\"|[^,]*)/g);
			my @array;
			foreach my $value (@spl){
				my @cell = $self->parse_line($value);
				push @array,\@cell;
			}
			$self->l_table(\@array);
			
		# ������
		} elsif($word2 eq "//"){
		
		# ����ʤ���
		} else {
			my @obj = $self->parse_line($line);
			$self->l_text(\@obj);
		}
	}
	
	# ʣ���Ԥ�����
	$self->multi_explanation;
	
	$self->end_parse;
}

#===============================================================================
# ʣ���Ԥ�����
#===============================================================================
sub multi_explanation {
	my $self = shift;
	my $line = shift;
	if($self->{dl_flag}==1 && (index($line,":")!=0 || !defined($line))){
		my @obj1 = $self->parse_line($self->{dt});
		my @obj2 = $self->parse_line($self->{dd});
		$self->l_explanation(\@obj1,\@obj2);
		$self->{dl_flag} = 0;
		$self->{dt} = "";
		$self->{dd} = "";
	}
}

#===============================================================================
# ����ʬ��ѡ���
#===============================================================================
sub parse_line {
	my $self   = shift;
	my $source = shift;
	my @array  = ();
	
	# �ץ饰����
	if($source =~ /{{((.|\s)+?)}}/){
		my $pre  = $`;
		my $post = $';
		if($pre ne ""){ push(@array,$self->parse_line($pre)); }
		my $plugin = &Util::parse_plugin($1);
		my $class  = $main::I_PLUGIN->{$plugin->{command}};
		if(defined($class)){
			push @array,$self->plugin($plugin);
		} else {
			push @array,$self->text("{{$1}}");
		}
		if($post ne ""){ push(@array,$self->parse_line($post)); }
		
	# �ܡ���ɡ�������å������ä���������
	} elsif($source =~ /((''')|('')|(==)|(__))(.+?)(\1)/){
		my $pre   = $`;
		my $post  = $';
		my $type  = $1;
		my $label = $6;
		if($pre ne ""){ push(@array,$self->parse_line($pre)); }
		if($type eq "'''"){
			push @array,$self->bold($label);
		} elsif($type eq "__"){
			push @array,$self->underline($label);
		} elsif($type eq "''"){
			push @array,$self->italic($label);
		} elsif($type eq "=="){
			push @array,$self->denialline($label);
		}
		if($post ne ""){ push(@array,$self->parse_line($post)); }
		
	# �ڡ�����̾���
	} elsif($source =~ /\[\[([^\[]+?)\|(.+?)\]\]/){
		my $pre   = $`;
		my $post  = $';
		my $label = $1;
		my $page  = $2;
		if($pre ne ""){ push(@array,$self->parse_line($pre)); }
		push @array,$self->wiki_anchor($page,$label);
		if($post ne ""){ push(@array,$self->parse_line($post)); }

	# URL��̾���
	} elsif($source =~ /\[([^\[]+?)\|((http|https|ftp|mailto):[a-zA-Z0-9\.,%~^_+\-%\/\?\(\)!\$&=:;\*#\@']*)\]/
	    ||  $source =~ /\[([^\[]+?)\|(file:[^\[\]]*)\]/
	    ||  $source =~ /\[([^\[]+?)\|((\/|\.\/|\.\.\/)+[a-zA-Z0-9\.,%~^_+\-%\/\?\(\)!\$&=:;\*#\@']*)\]/){
		my $pre   = $`;
		my $post  = $';
		my $label = $1;
		my $url   = $2;
		if($pre ne ""){ push(@array,$self->parse_line($pre)); }
		if(index($url,'"') >= 0 || index($url,'><') >= 0 || index($url, 'javascript:') >= 0){
			push @array,"<span class=\"error\">�����ʥ�󥯤Ǥ���</span>";
		} else {
			push @array,$self->url_anchor($url,$label);
		}
		if($post ne ""){ push(@array,$self->parse_line($post)); }
		
	# URL���
	} elsif($source =~ /(http|https|ftp|mailto):[a-zA-Z0-9\.,%~^_+\-%\/\?\(\)!\$&=:;\*#\@']*/
	    ||  $source =~ /\[([^\[]+?)\|(file:[^\[\]]*)\]/){
		my $pre   = $`;
		my $post  = $';
		my $url = $&;
		if($pre ne ""){ push(@array,$self->parse_line($pre)); }
		if(index($url,'"') >= 0 || index($url,'><') >= 0 || index($url, 'javascript:') >= 0){
			push @array,"<span class=\"error\">�����ʥ�󥯤Ǥ���</span>";
		} else {
			push @array,$self->url_anchor($url);
		}
		if($post ne ""){ push(@array,$self->parse_line($post)); }
		
	# �ڡ������
	} elsif($source =~ /\[\[([^\|]+?)\]\]/){
		my $pre   = $`;
		my $post  = $';
		my $page = $1;
		if($pre ne ""){ push(@array,$self->parse_line($pre)); }
		push @array,$self->wiki_anchor($page);
		if($post ne ""){ push(@array,$self->parse_line($post)); }

	# Ǥ�դ�URL���
	} elsif($source =~ /\[([^\[]+?)\|(.+?)\]/){
		my $pre   = $`;
		my $post  = $';
		my $label = $1;
		my $url   = $2;
		if($pre ne ""){ push(@array,$self->parse_line($pre)); }
		if(index($url,'"') >= 0 || index($url,'><') >= 0 || index($url, 'javascript:') >= 0){
			push @array,"<span class=\"error\">�����ʥ�󥯤Ǥ���</span>";
		} else {
			push @array,$self->url_anchor($url,$label);
		}
		if($post ne ""){ push(@array,$self->parse_line($post)); }
		
	# WikiName
	} elsif($main::WIKI_NAME==1 && $source =~ /[A-Z]+?[a-z]+?([A-Z]+?[a-z]+)+/){
		my $pre   = $`;
		my $post  = $';
		my $page  = $&;
		if($pre ne ""){ push(@array,$self->parse_line($pre)); }
		push @array,$self->wiki_anchor($page);
		if($post ne ""){ push(@array,$self->parse_line($post)); }
		
	} else {
		push @array,$self->text($source);
	}
	
	return @array;
}

#==============================================================================
# �ꥹ��
#==============================================================================
sub l_list {
	my $self  = shift;
	my $level = shift;
	my $obj   = shift;
	
	if($self->{para}==1){
		$self->{html} .= "</p>\n";
		$self->{para} = 0;
	}
	
	$self->end_verbatim;
	$self->end_table;
	$self->end_quote;
	$self->end_explan;
	
	my $html = join("",@$obj);
	my $plus = 1;
	
	if($level < $self->{level}){ $plus = -1; }
	if($level==$self->{level}){
		$self->{html} .= "</li>\n";
	}
	while($level != $self->{level}){
		if($plus==1){
			$self->{html} .= "<ul>\n";
			push(@{$self->{close_list}},"</ul>\n");
		} else {
			$self->{html} .= "</li>\n";
			$self->{html} .= pop(@{$self->{close_list}});
		}
		$self->{level} += $plus;
	}
	
	$self->{html} .= "<li>".$html;
}

#==============================================================================
# �ֹ��դ��ꥹ��
#==============================================================================
sub l_numlist {
	my $self  = shift;
	my $level = shift;
	my $obj   = shift;
	
	if($self->{para}==1){
		$self->{html} .= "</p>\n";
		$self->{para} = 0;
	}
	
	$self->end_verbatim;
	$self->end_table;
	$self->end_quote;
	$self->end_explan;
	
	my $html = join("",@$obj);
	my $plus = 1;
	
	if($level < $self->{level}){ $plus = -1; }
	if($level==$self->{level}){
		$self->{html} .= "</li>\n";
	}
	while($level != $self->{level}){
		if($plus==1){
			$self->{html} .= "<ol>\n";
			push(@{$self->{close_list}},"</ol>\n");
		} else {
			$self->{html} .= "</li>\n";
			$self->{html} .= pop(@{$self->{close_list}});
		}
		$self->{level} += $plus;
	}
	$self->{html} .= "<li>".$html;
}

#==============================================================================
# �ꥹ�Ȥν�λ
#==============================================================================
sub end_list {
	my $self  = shift;
	if ($self->{level}!=0) {
		$self->{html} .= "</li>\n";
		while($self->{level}!=0){
			$self->{html} .= pop(@{$self->{close_list}});
			$self->{level} += -1;
		}
	}
}

#==============================================================================
# �إåɥ饤��
#==============================================================================
sub l_headline {
	my $self  = shift;
	my $level = shift;
	my $obj   = shift;
	
	if($self->{para}==1){
		$self->{html} .= "</p>\n";
		$self->{para} = 0;
	}
	
	$self->end_list;
	$self->end_verbatim;
	$self->end_table;
	$self->end_quote;
	$self->end_explan;
	
	my $html  = join("",@$obj);
	
	if(!$self->{main}){
		$self->{html} .= "<h".($level+1).">".$html."</h".($level+1).">\n";
	} else {
		if($level==2){
			$self->{html} .= "<h".($level+1)."><a name=\"p".$self->{p_cnt}."\">".
			                 "<span class=\"sanchor\">_</span></a>".$html."</h".($level+1).">\n";
		} else {
			$self->{html} .= "<h".($level+1).">".
			                 "<a name=\"p".$self->{p_cnt}."\">".$html."</a>".
			                 "</h".($level+1).">\n";
		}
	}
	$self->{p_cnt}++;
}

#==============================================================================
# ��ʿ��
#==============================================================================
sub l_line {
	my $self = shift;
	
	$self->end_list;
	$self->end_verbatim;
	$self->end_table;
	$self->end_quote;
	$self->end_explan;
	
	$self->{html} .= "<hr>\n";
}

#==============================================================================
# ������ڤ�
#==============================================================================
sub l_paragraph {
	my $self = shift;
	
	$self->end_list;
	$self->end_verbatim;
	$self->end_table;
	$self->end_quote;
	$self->end_explan;
	
	if($self->{para}==1){
		$self->{html} .= "</p>\n";
		$self->{para} = 0;
	}
}

#==============================================================================
# �����ѥƥ�����
#==============================================================================
sub l_verbatim {
	my $self  = shift;
	my $text  = shift;
	
	if($self->{para}==1){
		$self->{html} .= "</p>\n";
		$self->{para} = 0;
	}
	
	$self->end_list;
	$self->end_table;
	$self->end_quote;
	$self->end_explan;
	
	$self->{pre} .= Util::escapeHTML($text)."\n";
}

sub end_verbatim {
	my $self  = shift;
	if($self->{pre} ne ""){
		$self->{html} .= "<pre>".$self->{pre}."</pre>";
		$self->{pre} = "";
	}
}

#==============================================================================
# �ơ��֥�
#==============================================================================
sub l_table {
	my $self = shift;
	my $row  = shift;
	$self->end_list;
	$self->end_verbatim;
	$self->end_quote;
	$self->end_explan;
	
	if($self->{table}==0){
		$self->{table}=1;
		$self->{html} .= "<table>\n";
		$self->{html} .= "<tr>\n";
		foreach(@$row){
			my $html = join("",@$_);
			$self->{html} .= "<th>".$html."</th>\n";
		}
		$self->{html} .= "</tr>\n";
	} else {
		$self->{table}=2;
		$self->{html} .= "<tr>\n";
		foreach(@$row){
			my $html = join("",@$_);
			$self->{html} .= "<td>".$html."</td>\n";
		}
		$self->{html} .= "</tr>\n";
	}
}

sub end_table {
	my $self = shift;
	if($self->{table}!=0){
		$self->{table} = 0;
		$self->{html} .= "</table>\n";
	}
}

#==============================================================================
# �ѡ�����λ���ν���
#==============================================================================
sub end_parse {
	my $self = shift;
	$self->end_list;
	$self->end_verbatim;
	$self->end_table;
	$self->end_quote;
	$self->end_explan;
	
	if($self->{para}==1){
		$self->{html} .= "</p>\n";
		$self->{para} = 0;
	}
}

#==============================================================================
# �Խ񼰤˳������ʤ���
#==============================================================================
sub l_text {
	my $self = shift;
	my $obj  = shift;
	$self->end_list;
	$self->end_verbatim;
	$self->end_table;
	$self->end_quote;
	$self->end_explan;
	my $html = join("",@$obj);
	
	if($self->{para}==0){
		$self->{html} .= "<p>";
		$self->{para} = 1;
	}
	$self->{html} .= $html;
}

#==============================================================================
# ����
#==============================================================================
sub l_quotation {
	my $self = shift;
	my $obj  = shift;
	$self->end_list;
	$self->end_verbatim;
	$self->end_table;
	$self->end_explan;
	my $html = join("",@$obj);
	$self->{quote} .= "<p>".$html."</p>\n";
}

sub end_quote {
	my $self = shift;
	if($self->{quote} ne ""){
		$self->{html} .= "<blockquote>".$self->{quote}."</blockquote>\n";
		$self->{quote} = "";
	}
}

#==============================================================================
# ����
#==============================================================================
sub l_explanation {
	my $self = shift;
	my $obj1 = shift;
	my $obj2 = shift;
	
	if($self->{para}==1){
		$self->{html} .= "</p>";
		$self->{para} = 0;
	}

	$self->end_list;
	$self->end_verbatim;
	$self->end_table;
	$self->end_quote;
	
	if($self->{explan}==0){
		$self->{explan}=1;
		$self->{html} .= "<dl>\n";
	}
	
	my $html1 = join("",@$obj1);
	my $html2 = join("",@$obj2);
	
	$self->{html} .= "<dt>".$html1."</dt>\n<dd>".$html2."</dd>\n";
}

sub end_explan {
	my $self = shift;
	if($self->{explan}!=0){
		$self->{explan} = 0;
		$self->{html} .= "</dl>\n";
	}
}

#==============================================================================
# �ܡ����
#==============================================================================
sub bold {
	my $self = shift;
	my $text = shift;
	return "<strong>".join("",$self->parse_line($text))."</strong>";
}

#==============================================================================
# ������å�
#==============================================================================
sub italic {
	my $self = shift;
	my $text = shift;
	return "<em>".join("",$self->parse_line($text))."</em>";
}

#==============================================================================
# ����
#==============================================================================
sub underline {
	my $self = shift;
	my $text = shift;
	return "<ins>".join("",$self->parse_line($text))."</ins>";
}

#==============================================================================
# �Ǥ��ä���
#==============================================================================
sub denialline {
	my $self = shift;
	my $text = shift;
	return "<del>".join("",$self->parse_line($text))."</del>";
}

#==============================================================================
# URL����
#==============================================================================
sub url_anchor {
	my $self = shift;
	my $url  = shift;
	my $name = shift;
	
	if($name eq ""){
		$name = $url;
	}
	
	if($url eq $name && $url=~/\.(gif|jpg|jpeg|bmp|png)$/i){
		return "<img src=\"".$url."\">";
	} else {
		return "<a href=\"$url\">".Util::escapeHTML($name)."</a>";
	}
}

#==============================================================================
# Wiki�ڡ����ؤΥ���
#==============================================================================
sub wiki_anchor {
	my $self = shift;
	my $page = shift;
	my $name = shift;
	
	if(!defined($name) || $name eq ""){
		$name = $page;
	}
	
	if(&Wiki::exists_page($page)){
		return "<a href=\"$main::MAIN_SCRIPT?p=".&Util::url_encode($page)."\" class=\"wikipage\">".
		       &Util::escapeHTML($name)."</a>";
	} else {
		return "<span class=\"nopage\">".&Util::escapeHTML($name)."</span>".
		       "<a href=\"$main::MAIN_SCRIPT?p=".&Util::url_encode($page)."\">?</a>";
	}
}

#==============================================================================
# �����Υƥ�����
#==============================================================================
sub text {
	my $self = shift;
	my $text = shift;
	return &Util::escapeHTML($text);
}

#==============================================================================
# ����饤��ץ饰����
#==============================================================================
sub plugin {
	my $self   = shift;
	my $plugin = shift;
	
	my $func_ref = $main::I_PLUGIN->{$plugin->{command}};
	my $result = &$func_ref(@{$plugin->{args}});
	if(defined($result) && $result ne ""){
		return ($result);
	}
	
	return undef;
}

#==============================================================================
# �ѥ饰��եץ饰����
#==============================================================================
sub l_plugin {
	my $self   = shift;
	my $plugin = shift;
	
	if($self->{para}==1){
		$self->{html} .= "</p>\n";
		$self->{para} = 0;
	}
	
	$self->end_list;
	$self->end_verbatim;
	$self->end_table;
	$self->end_quote;
	$self->end_explan;
	
	my $func_ref = $main::P_PLUGIN->{$plugin->{command}};
	my $result = &$func_ref(@{$plugin->{args}});
	if(defined($result) && $result ne ""){
		$self->{html} .= $result;
	}
}

#==============================================================================
# ���᡼��
#==============================================================================
sub l_image {
	my $self = shift;
	my $page = shift;
	my $file = shift;
	my $wiki = $self->{wiki};
	
	if($self->{para}==1){
		$self->{html} .= "</p>";
		$self->{para} = 0;
	}
	
	$self->end_list;
	$self->end_verbatim;
	$self->end_table;
	$self->end_quote;
	$self->end_explan;
	
	$self->{html} .= "<img src=\"".$wiki->config('script_name')."?action=ATTACH&amp;".
	                 "page=".&Util::url_encode($page)."&amp;file=".&Util::url_encode($file)."\">";
}


################################################################################
#
# �桼�ƥ���ƥ��ؿ����󶡤���ѥå�����
#
################################################################################
package Util;
#===============================================================================
#  �������Ϥ��줿ʸ�����URL���󥳡��ɤ����֤��ޤ���
#===============================================================================
sub url_encode {
	my $retstr = shift;
	$retstr =~ s/([^ 0-9A-Za-z])/sprintf("%%%.2X", ord($1))/eg;
	$retstr =~ tr/ /+/;
	return $retstr;
}

#===============================================================================
#  �������Ϥ��줿ʸ�����URL�ǥ����ɤ����֤��ޤ���
#===============================================================================
sub url_decode{
	my $retstr = shift;
	$retstr =~ tr/+/ /;
	$retstr =~ s/%([A-Fa-f0-9]{2})/pack("c",hex($1))/ge;
	return $retstr;
}

#===============================================================================
#  �������Ϥ��줿ʸ�����HTML�����򥨥������פ����֤��ޤ���
#===============================================================================
sub escapeHTML {
	my($retstr) = shift;
	my %table = (
		'&' => '&amp;',
		'"' => '&quot;',
		'<' => '&lt;',
		'>' => '&gt;',
	);
	$retstr =~ s/([&\"<>])/$table{$1}/go;
	return $retstr;
}


#===============================================================================
# ���դ�ե����ޥåȤ��ޤ���
#===============================================================================
sub format_date {
	my $t = shift;
	my ($sec, $min, $hour, $mday, $mon, $year) = localtime($t);
	return sprintf("%04dǯ%02d��%02d�� %02d��%02dʬ%02d��",
	               $year+1900,$mon+1,$mday,$hour,$min,$sec);
}

#===============================================================================
# ʸ�����ξü�ζ�����ڤ���Ȥ��ޤ���
#===============================================================================
sub trim {
	my $text = shift;
	if(!defined($text)){
		return "";
	}
	$text =~ s/^(?:\s)+//o;
	$text =~ s/(?:\s)+$//o;
	return $text;
}


#===============================================================================
# ������������ʸ����Τߤ�������ޤ���
#===============================================================================
sub delete_tag {
	my $text = shift;
	$text =~ s/<(.|\s)+?>//g;
	return $text;
}

#===============================================================================
# ���ͤ��ɤ��������å����ޤ���
#===============================================================================
sub check_numeric {
	my $text = shift;
	if($text =~ /^[0-9]+$/){
		return 1;
	} else {
		return 0;
	}
}

#===============================================================================
# ���顼������
#===============================================================================
sub error {
	my $error = shift;
	
	print "Content-Type: text/html;charset=EUC-JP\n\n";
	print "<html>\n";
	print "<head><title>���顼 - FSWikiLite</title></head>\n";
	print "<body>\n";
	print "<h1>���顼��ȯ�����ޤ���</h1>\n";
	print "<pre>\n";
	print &Util::escapeHTML($error);
	print "</pre>\n";
	print "</body><html>\n";
	
	exit;
}

#===============================================================================
# �������ä��ɤ��������å����ޤ���
#===============================================================================
sub handyphone {
	my $ua = $ENV{'HTTP_USER_AGENT'};
	if(!defined($ua)){
		return 0;
	}
	if($ua=~/^DoCoMo\// || $ua=~ /^J-PHONE\// || $ua=~ /UP\.Browser/){
		return 1;
	} else {
		return 0;
	}
}

#===============================================================================
# ����饤��ץ饰�����ѡ������ƥ��ޥ�ɤȰ�����ʬ��
#===============================================================================
sub parse_plugin {
	my $text = shift;
	my ($cmd,@args_tmp) = split(/ /,$text);
	my $args_txt = &Util::trim(join(" ",@args_tmp));
	
	my @ret_args;
	my $tmp    = "";
	my $escape = 0;
	my $quote  = 0;
	
	for(my $i=0;$i<length($args_txt);$i++){
		my $c = substr($args_txt,$i,1);
		
		if($quote!=1 && $c eq ","){
			if($tmp ne ""){
				push(@ret_args,$tmp);
				$tmp = "";
				$quote = 0;
			}
		} elsif($quote==1 && $c eq "\\"){
			if($escape==0){
				$escape = 1;
			} else {
				$tmp .= $c;
				$escape = 0;
			}
		} elsif($quote==0 && $c eq '"'){
			if($tmp eq ""){
				$quote = 1;
			} else {
				$tmp .= $c;
			}
		} elsif($quote==1 && $c eq '"'){
			if($escape==1){
				$tmp .= $c;
				$escape = 0;
			} else {
				$quote = 2;
			}
		} elsif($quote==2){
			return {error=>"����饤��ץ饰����ι�ʸ�������Ǥ���"};
		} else {
			$tmp .= $c;
		}
	}
	
	if($tmp ne ""){
		push(@ret_args,$tmp);
	}
	
	return {command=>$cmd,args=>\@ret_args};
}

1;
