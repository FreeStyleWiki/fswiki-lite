################################################################################
#
# FSWikiLite 共通関数ファイル
#
################################################################################
require "./lib/cgi-lib.pl";
require "./lib/jcode.pl";
require "./lib/mimew.pl";
require "./lib/setup.pl";
#-------------------------------------------------------------------------------
# 引数で渡したページに遷移
#-------------------------------------------------------------------------------
sub redirect {
	my $page = shift;
	my $url  = "$MAIN_SCRIPT?p=".&Util::url_encode($page);
	&redirectURL($url);
}

#-------------------------------------------------------------------------------
# 引数で渡したURLに遷移
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
# ヘッダを表示
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
	print "    <a href=\"$EDIT_SCRIPT?a=new\">新規</a>\n";
	if($show==1){
		print "    <a href=\"$EDIT_SCRIPT?a=edit&p=".&Util::url_encode($in{"p"})."\">編集</a>\n";
	}
	print "    <a href=\"$MAIN_SCRIPT?a=search\">検索</a>\n";
	print "    <a href=\"$MAIN_SCRIPT?a=list\">一覧</a>\n";
	print "    <a href=\"$MAIN_SCRIPT?p=Help\">ヘルプ</a>\n";
	print "  </span>\n";
	print "</div>\n";
	
	print "<h1>".&Util::escapeHTML($title)."</h1>\n";
	if(&Wiki::exists_page("Menu")){
		print "<div class=\"main\">\n";
	}
	
}

#-------------------------------------------------------------------------------
# フッタを表示
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
# Wiki関連の関数を提供するパッケージ
#
###############################################################################
package Wiki;
#-------------------------------------------------------------------------------
# ページを取得
#-------------------------------------------------------------------------------
sub get_page {
	my $page = &Util::url_encode(shift);
	
	open(DATA,"$main::DATA_DIR/$page.wiki") or &Util::error("$main::DATA_DIR/$page.wikiのオープンに失敗しました。");
	my $content = "";
	while(<DATA>){
		$content .= $_;
	}
	close(DATA);
	
	return $content;
}
#-------------------------------------------------------------------------------
# ページを保存
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
	
	# バックアップファイルを作成
	if(-e "$main::DATA_DIR/$enc_page.wiki"){
		open(BACKUP,">$main::BACKUP_DIR/$enc_page.bak") or &Util::error("$main::BACKUP_DIR/$enc_page.bakのオープンに失敗しました。");
		open(DATA  ,"$main::DATA_DIR/$enc_page.wiki")   or &Util::error("$main::DATA_DIR/$enc_page.wikiのオープンに失敗しました。");
		while(<DATA>){
			print BACKUP $_;
		}
		close(DATA);
		close(BACKUP);
	}
	
	# 入力内容を保存
	open(DATA,">$main::DATA_DIR/$enc_page.wiki") or &Util::error("$main::DATA_DIR/$enc_page.wikiのオープンに失敗しました。");
	print DATA $source;
	close(DATA);
	
	&send_mail($action,$page);
}
#-------------------------------------------------------------------------------
# ページを削除
#-------------------------------------------------------------------------------
sub remove_page {
	my $page     = shift;
	my $enc_page = &Util::url_encode($page);
	unlink("$main::DATA_DIR/$enc_page.wiki") or &Util::error("$main::DATA_DIR/$enc_page.wikiの削除に失敗しました。");
	
	&send_mail('DELETE',$page);
}
#-------------------------------------------------------------------------------
# メール送信
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
		$subject = "[FSWikiLite]$pageが作成されました";
		
	} elsif($action eq 'MODIFY'){
		$subject = "[FSWikiLite]$pageが更新されました";
		
	} elsif($action eq 'DELETE'){
		$subject = "[FSWikiLite]$pageが削除されました";
	}
	
	# MIMEエンコード
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
			$body .= "以下は変更前のソースです。\n".
			         "-----------------------------------------------------\n";
			open(BACKUP,"$main::BACKUP_DIR/$enc_page.bak");
			while(my $line = <BACKUP>){
				$body .= $line;
			}
			close(BACKUP);
		}
	}
	
	# 文字コードの変換(jcode.plを使用する)
	&jcode::convert(\$body,'jis');
	
	open(MAIL,"| $main::SEND_MAIL $main::ADMIN_MAIL");
	print MAIL $head;
	print MAIL $body;
	close(MAIL);
}
#-------------------------------------------------------------------------------
# ページの一覧を取得
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
# ページの更新日時を取得
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
# ページが存在するかどうか
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
# Wikiソースを渡してHTMLを取得します
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
# HTMLパーサ
#
###############################################################################
package HTMLParser;
#==============================================================================
# コンストラクタ
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
# パース
#===============================================================================
sub parse {
	my $self   = shift;
	my $source = shift;
	
	$source =~ s/\r//g;
	my @lines = split(/\n/,$source);
	
	foreach my $line (@lines){
		chomp $line;
		
		# 複数行の説明
		$self->multi_explanation($line);
		
		my $word1 = substr($line,0,1);
		my $word2 = substr($line,0,2);
		my $word3 = substr($line,0,3);
		
		# 空行
		if($line eq ""){
			$self->l_paragraph();
			next;
		}
		
		# パラグラフプラグイン
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
			
		# 見出し
		} elsif($word3 eq "!!!"){
			my @obj = $self->parse_line(substr($line,3));
			$self->l_headline(1,\@obj);
			
		} elsif($word2 eq "!!"){
			my @obj = $self->parse_line(substr($line,2));
			$self->l_headline(2,\@obj);
			
		} elsif($word1 eq "!"){
			my @obj = $self->parse_line(substr($line,1));
			$self->l_headline(3,\@obj);

		# 項目
		} elsif($word3 eq "***"){
			my @obj = $self->parse_line(substr($line,3));
			$self->l_list(3,\@obj);
			
		} elsif($word2 eq "**"){
			my @obj = $self->parse_line(substr($line,2));
			$self->l_list(2,\@obj);
			
		} elsif($word1 eq "*"){
			my @obj = $self->parse_line(substr($line,1));
			$self->l_list(1,\@obj);
			
		# 番号付き項目
		} elsif($word3 eq "+++"){
			my @obj = $self->parse_line(substr($line,3));
			$self->l_numlist(3,\@obj);
			
		} elsif($word2 eq "++"){
			my @obj = $self->parse_line(substr($line,2));
			$self->l_numlist(2,\@obj);
			
		} elsif($word1 eq "+"){
			my @obj = $self->parse_line(substr($line,1));
			$self->l_numlist(1,\@obj);
			
		# 水平線
		} elsif($line eq "----"){
			$self->l_line();
		
		# 引用
		} elsif($word2 eq '""'){
			my @obj = $self->parse_line(substr($line,2));
			$self->l_quotation(\@obj);
			
		# 説明
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
			
		# テーブル
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
			
		# コメント
		} elsif($word2 eq "//"){
		
		# 何もない行
		} else {
			my @obj = $self->parse_line($line);
			$self->l_text(\@obj);
		}
	}
	
	# 複数行の説明
	$self->multi_explanation;
	
	$self->end_parse;
}

#===============================================================================
# 複数行の説明
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
# １行分をパース
#===============================================================================
sub parse_line {
	my $self   = shift;
	my $source = shift;
	my @array  = ();
	
	# プラグイン
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
		
	# ボールド、イタリック、取り消し線、下線
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
		
	# ページ別名リンク
	} elsif($source =~ /\[\[([^\[]+?)\|(.+?)\]\]/){
		my $pre   = $`;
		my $post  = $';
		my $label = $1;
		my $page  = $2;
		if($pre ne ""){ push(@array,$self->parse_line($pre)); }
		push @array,$self->wiki_anchor($page,$label);
		if($post ne ""){ push(@array,$self->parse_line($post)); }

	# URL別名リンク
	} elsif($source =~ /\[([^\[]+?)\|((http|https|ftp|mailto):[a-zA-Z0-9\.,%~^_+\-%\/\?\(\)!\$&=:;\*#\@']*)\]/
	    ||  $source =~ /\[([^\[]+?)\|(file:[^\[\]]*)\]/
	    ||  $source =~ /\[([^\[]+?)\|((\/|\.\/|\.\.\/)+[a-zA-Z0-9\.,%~^_+\-%\/\?\(\)!\$&=:;\*#\@']*)\]/){
		my $pre   = $`;
		my $post  = $';
		my $label = $1;
		my $url   = $2;
		if($pre ne ""){ push(@array,$self->parse_line($pre)); }
		if(index($url,'"') >= 0 || index($url,'><') >= 0 || index($url, 'javascript:') >= 0){
			push @array,"<span class=\"error\">不正なリンクです。</span>";
		} else {
			push @array,$self->url_anchor($url,$label);
		}
		if($post ne ""){ push(@array,$self->parse_line($post)); }
		
	# URLリンク
	} elsif($source =~ /(http|https|ftp|mailto):[a-zA-Z0-9\.,%~^_+\-%\/\?\(\)!\$&=:;\*#\@']*/
	    ||  $source =~ /\[([^\[]+?)\|(file:[^\[\]]*)\]/){
		my $pre   = $`;
		my $post  = $';
		my $url = $&;
		if($pre ne ""){ push(@array,$self->parse_line($pre)); }
		if(index($url,'"') >= 0 || index($url,'><') >= 0 || index($url, 'javascript:') >= 0){
			push @array,"<span class=\"error\">不正なリンクです。</span>";
		} else {
			push @array,$self->url_anchor($url);
		}
		if($post ne ""){ push(@array,$self->parse_line($post)); }
		
	# ページリンク
	} elsif($source =~ /\[\[([^\|]+?)\]\]/){
		my $pre   = $`;
		my $post  = $';
		my $page = $1;
		if($pre ne ""){ push(@array,$self->parse_line($pre)); }
		push @array,$self->wiki_anchor($page);
		if($post ne ""){ push(@array,$self->parse_line($post)); }

	# 任意のURLリンク
	} elsif($source =~ /\[([^\[]+?)\|(.+?)\]/){
		my $pre   = $`;
		my $post  = $';
		my $label = $1;
		my $url   = $2;
		if($pre ne ""){ push(@array,$self->parse_line($pre)); }
		if(index($url,'"') >= 0 || index($url,'><') >= 0 || index($url, 'javascript:') >= 0){
			push @array,"<span class=\"error\">不正なリンクです。</span>";
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
# リスト
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
# 番号付きリスト
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
# リストの終了
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
# ヘッドライン
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
# 水平線
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
# 段落区切り
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
# 整形済テキスト
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
# テーブル
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
# パース終了時の処理
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
# 行書式に該当しない行
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
# 引用
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
# 説明
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
# ボールド
#==============================================================================
sub bold {
	my $self = shift;
	my $text = shift;
	return "<strong>".join("",$self->parse_line($text))."</strong>";
}

#==============================================================================
# イタリック
#==============================================================================
sub italic {
	my $self = shift;
	my $text = shift;
	return "<em>".join("",$self->parse_line($text))."</em>";
}

#==============================================================================
# 下線
#==============================================================================
sub underline {
	my $self = shift;
	my $text = shift;
	return "<ins>".join("",$self->parse_line($text))."</ins>";
}

#==============================================================================
# 打ち消し線
#==============================================================================
sub denialline {
	my $self = shift;
	my $text = shift;
	return "<del>".join("",$self->parse_line($text))."</del>";
}

#==============================================================================
# URLアンカ
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
# Wikiページへのアンカ
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
# ただのテキスト
#==============================================================================
sub text {
	my $self = shift;
	my $text = shift;
	return &Util::escapeHTML($text);
}

#==============================================================================
# インラインプラグイン
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
# パラグラフプラグイン
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
# イメージ
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
# ユーティリティ関数を提供するパッケージ
#
################################################################################
package Util;
#===============================================================================
#  引数で渡された文字列をURLエンコードして返します。
#===============================================================================
sub url_encode {
	my $retstr = shift;
	$retstr =~ s/([^ 0-9A-Za-z])/sprintf("%%%.2X", ord($1))/eg;
	$retstr =~ tr/ /+/;
	return $retstr;
}

#===============================================================================
#  引数で渡された文字列をURLデコードして返します。
#===============================================================================
sub url_decode{
	my $retstr = shift;
	$retstr =~ tr/+/ /;
	$retstr =~ s/%([A-Fa-f0-9]{2})/pack("c",hex($1))/ge;
	return $retstr;
}

#===============================================================================
#  引数で渡された文字列のHTMLタグをエスケープして返します。
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
# 日付をフォーマットします。
#===============================================================================
sub format_date {
	my $t = shift;
	my ($sec, $min, $hour, $mday, $mon, $year) = localtime($t);
	return sprintf("%04d年%02d月%02d日 %02d時%02d分%02d秒",
	               $year+1900,$mon+1,$mday,$hour,$min,$sec);
}

#===============================================================================
# 文字列の両端の空白を切り落とします。
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
# タグを削除して文字列のみを取得します。
#===============================================================================
sub delete_tag {
	my $text = shift;
	$text =~ s/<(.|\s)+?>//g;
	return $text;
}

#===============================================================================
# 数値かどうかチェックします。
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
# エラーを通知
#===============================================================================
sub error {
	my $error = shift;
	
	print "Content-Type: text/html;charset=EUC-JP\n\n";
	print "<html>\n";
	print "<head><title>エラー - FSWikiLite</title></head>\n";
	print "<body>\n";
	print "<h1>エラーが発生しました</h1>\n";
	print "<pre>\n";
	print &Util::escapeHTML($error);
	print "</pre>\n";
	print "</body><html>\n";
	
	exit;
}

#===============================================================================
# 携帯電話かどうかチェックします。
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
# インラインプラグインをパースしてコマンドと引数に分割
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
			return {error=>"インラインプラグインの構文が不正です。"};
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
