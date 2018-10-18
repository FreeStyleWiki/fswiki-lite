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
	print "    <a href=\"".&Wiki::create_url({p=>"FrontPage"})."\">FrontPage</a>\n";
	print "    <a href=\"".&Wiki::create_url({a=>"new"})."\">新規</a>\n";
	if($show==1){
		print "    <a href=\"".&Wiki::create_url({a=>"edit",p=>$in{"p"}})."\">編集</a>\n";
	}
	print "    <a href=\"".&Wiki::create_url({a=>"search"})."\">検索</a>\n";
	print "    <a href=\"".&Wiki::create_url({a=>"list"})."\">一覧</a>\n";
	print "    <a href=\"".&Wiki::create_url({p=>"Help"})."\">ヘルプ</a>\n";
	print "  </span>\n";
	print "</div>\n";
	
	print "<h1>".&Util::escapeHTML($title)."</h1>\n";
	if(&Wiki::page_exists("Menu")){
		print "<div class=\"main\">\n";
	}
}

#-------------------------------------------------------------------------------
# フッタを表示
#-------------------------------------------------------------------------------
sub print_footer {
	if(&Wiki::page_exists("Menu")){
		print "</div>\n";
		print "<div class=\"sidebar\">\n";
		print &Wiki::process_wiki(&Wiki::get_page("Menu"));
		print "</div>\n";
	}
	print "<div class=\"footer\">Powered by <a href=\"".$main::SITE_URL."\">FreeStyleWikiLite ".$main::VERSION."</a></div>\n";
	print "</body></html>\n";
}

#-------------------------------------------------------------------------------
# 旧Ver(0.0.11)互換性維持
# 次期バージョンで削除されます。
#-------------------------------------------------------------------------------
sub redirect { return &Wiki::redirect($@); }
sub redirectURL { return &Wiki::redirectURL($@); }

package Wiki;
sub exists_page { return &page_exists(shift); }
sub send_mail { return &Util::send_mail($@); }

package HTMLParser;

package Util;
sub parse_plugin { return &Wiki::parse_inline_plugin($@); }

###############################################################################
#
# Wiki関連の関数を提供するパッケージ
#
###############################################################################
package Wiki;

local @current_parser = [];

#==============================================================================
# プラグインの情報を取得します
#==============================================================================
sub get_plugin_info {
	my $name = shift;
	return defined($main::P_PLUGIN->{$name}) ? {FUNCTION=>$main::P_PLUGIN->{$name}, TYPE=>'paragraph'} :
	       defined($main::I_PLUGIN->{$name}) ? {FUNCTION=>$main::I_PLUGIN->{$name}, TYPE=>'inline'   } :
	       defined($main::B_PLUGIN->{$name}) ? {FUNCTION=>$main::B_PLUGIN->{$name}, TYPE=>'block'    } :
	       {};
}

#==============================================================================
# Wikiソースを渡してHTMLを取得します
#==============================================================================
sub process_wiki {
	my $source  = shift;
	my $mainflg = shift;
	my $parser  = HTMLParser->new($mainflg);
	
	# 裏技用(プラグイン内部からパーサを使う場合)
	push(@current_parser, $parser);
	
	$parser->parse($source);
	
	# パーサの参照を解放
	pop(@current_parser);
	
	return $parser->{html};
}

#==============================================================================
# パース中の場合、現在有効なHTMLParserのインスタンスを返却します。
# パース中の内容をプラグインから変更したい場合に使用します。
#==============================================================================
sub get_current_parser {
	return $current_parser[$#current_parser];
}

#===============================================================================
# インラインプラグインをパースしてコマンドと引数に分割
#===============================================================================
sub parse_inline_plugin {
	my $text = shift;
	my ($cmd, @args_tmp) = split(/ /,$text);
	my $args_txt = &Util::trim(join(" ",@args_tmp));
	if($cmd =~ s/\}\}(.*?)$//){
		return { command=>$cmd, args=>[], post=>"$1 $args_txt"};
	}
	
	my @ret_args;
	my $tmp    = "";
	my $escape = 0;
	my $quote  = 0;
	my $i      = 0;
	
	for($i = 0; $i<length($args_txt); $i++){
		my $c = substr($args_txt,$i,1);
		if($quote!=1 && $c eq ","){
			if($quote==3){
				$tmp .= '}';
			}
			push(@ret_args,$tmp);
			$tmp = "";
			$quote = 0;
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
		} elsif(($quote==0 || $quote==2) && $c eq '}'){
			$quote = 3;
		} elsif($quote==3){
			if($c eq '}'){
				last;
			} else {
				$tmp .= '}'.$c;
				$quote = 0;
			}
		} elsif($quote==2){
			return {error=>"インラインプラグインの構文が不正です。"};
		} else {
			$tmp .= $c;
			$escape = 0;
		}
	}
	
	if($quote!=3){
		my $info = &Wiki::get_plugin_info($cmd);
		return undef if (defined($info->{TYPE}) && $info->{TYPE} ne 'block');
	}
	
	if($tmp ne ""){
		push(@ret_args,$tmp);
	}
	
	return { command=>$cmd, args=>\@ret_args, 
		post=>substr($args_txt, $i + 1, length($args_txt) - $i)};
}

#==============================================================================
# ページ表示のURLを生成
#==============================================================================
sub create_page_url {
	my $page = shift;
	return create_url({p=>$page});
}

#==============================================================================
# 任意のURLを生成
#==============================================================================
sub create_url {
	my $params = shift;
	my $script = shift;
	my $url    = '';
	my $query  = '';
	my $action = '';
	foreach my $key (keys(%$params)){
		my $val = $params->{$key};
		if ($key eq 'a') {
			$action = $val;
		}
		if($query ne ''){
			$query .= '&amp;';
		}
		$query .= Util::url_encode($key)."=".Util::url_encode($val);
	}
	if(!defined($script)){
		if ($action =~ /^(edit|new|delconf)$/){
			$script = $main::EDIT_SCRIPT;
		}else{
			$script = $main::MAIN_SCRIPT;
		}
	}
	$url = $script;
	if($query ne ''){
		$url .= '?'.$query; 
	}
	return $url;
}

#==============================================================================
# ページの一覧を取得
#==============================================================================
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

#==============================================================================
# ページの更新日時を取得
#==============================================================================
sub get_last_modified {
	my $page = shift;
	if(&page_exists($page)){
		my $file = sprintf("%s/%s.wiki",$main::DATA_DIR,&Util::url_encode($page));
		my @stat = stat($file);
		return $stat[9];
	} else {
		return undef;
	}
}

#==============================================================================
# ページを取得
#==============================================================================
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
#==============================================================================
# ページを保存
#==============================================================================
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
	
	&Util::send_mail($action,$page);
}

#==============================================================================
# ページが存在するかどうか
#==============================================================================
sub page_exists {
	my $page = &Util::url_encode(shift);
	if(-e "$main::DATA_DIR/$page.wiki"){
		return 1;
	} else {
		return 0;
	}
}

#==============================================================================
# 引数で渡したページに遷移
#==============================================================================
sub redirect {
	my $page = shift;
	my $url  = &Wiki::create_url({p=>$page});
	&redirectURL($url);
}

#==============================================================================
# 引数で渡したURLに遷移
#==============================================================================
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

#==============================================================================
# ページを削除
#==============================================================================
sub remove_page {
	my $page     = shift;
	my $enc_page = &Util::url_encode($page);
	unlink("$main::DATA_DIR/$enc_page.wiki") or &Util::error("$main::DATA_DIR/$enc_page.wikiの削除に失敗しました。");
	
	&Util::send_mail('DELETE',$page);
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
	
	$self->{dl_flag} = 0;
	$self->{dt} = "";
	$self->{dd} = "";
	
	$self->{html}  = "";
	$self->{pre}   = "";
	$self->{quote} = "";
	$self->{table} = 0;
	$self->{level} = 0;
	$self->{list}  = 0;
	$self->{para}  = 0;
	$self->{p_cnt} = 0;
	$self->{main}  = $mainflg;
	return bless $self,$class;
}

#===============================================================================
# パース
#===============================================================================
sub parse {
	my $self   = shift;
	my $source = shift;
	
	$self->start_parse;
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
		if($line eq "" && !$self->{block}){
			$self->l_paragraph();
			next;
		}
		
		# ブロック書式のエスケープ
		if(!$self->{block} && ($word2 eq "\\\\" || $word1 eq "\\")){
			my @obj = $self->parse_line(substr($line, 1));
			$self->l_text(\@obj);
			next;
		}
		
		# パラグラフプラグイン
		if($line =~ /^\{\{(.+\}\})$/){
			if(!$self->{block}){
				my $plugin = &Wiki::parse_inline_plugin($1);
				my $info   = &Wiki::get_plugin_info($plugin->{command});
				if($info->{TYPE} eq "paragraph"){
					$self->l_plugin($plugin);
				} else {
					my @obj = $self->parse_line($line);
					$self->l_text(\@obj);
				}
				next;
			}
		} elsif($line =~ /^\{\{(.+)$/){
			if ($self->{block}) {
				my $plugin = &Wiki::parse_inline_plugin($1);
				my $info   = &Wiki::get_plugin_info($plugin->{command});
				$self->{block}->{level}++ if($info->{TYPE} eq "block");
				$self->{block}->{args}->[0] .= $line."\n";
				next;
			}
			my $plugin = &Wiki::parse_inline_plugin($1);
			my $info   = &Wiki::get_plugin_info($plugin->{command});
			if($info->{TYPE} eq "block"){
				unshift(@{$plugin->{args}}, "");
				$self->{block} = $plugin;
				$self->{block}->{level} = 0;
			} else {
				my @obj = $self->parse_line($line);
				$self->l_text(\@obj);
			}
			next;
		}
		if($self->{block}){
			if($line eq "}}"){
				if ($self->{block}->{level} > 0) {
					$self->{block}->{level}--;
					$self->{block}->{args}->[0] .= $line."\n";
					next;
				}
				my $plugin = $self->{block};
				delete($self->{block});
				$self->l_plugin($plugin);
			} else {
				$self->{block}->{args}->[0] .= $line."\n";
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
			if($self->{dt} ne "" || $self->{dd} ne ""){
				$self->multi_explanation;
			}
			if(index($line,"::")==0){
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
	
	# パース中のブロックプラグインがあった場合、とりあえず評価しておく？
	if($self->{block}){
		my $plugin = $self->{block};
		delete($self->{block});
		$self->l_plugin($plugin);
	}
	
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
	my ($self, $source) = @_;

	return () if (not defined $source);

	my @array = ();
	my $pre   = q{};
	my @parsed = ();

	# $source が空になるまで繰り返す。
	SOURCE:
	while ($source ne q{}) {

		# どのインライン Wiki 書式の先頭にも match しない場合
		if (!($source =~ /^(.*?)((?:\{\{|\[\[?|https?:|mailto:|f(?:tp:|ile:)|'''?|==|__|<<).*)$/)) {
			# WikiName検索・置換処理のみ実施して終了する
			push @array, $self->_parse_line_wikiname($pre . $source);
			return @array;
		}

		$pre   .= $1;	# match しなかった先頭部分は溜めておいて後で処理する
		$source = $2;	# match 部分は後続処理にて詳細チェックを行う
		@parsed = ();

		# プラグイン
		if ($source =~ /^\{\{/) {
			$source = $';
			my $plugin = &Wiki::parse_inline_plugin($source);
			unless($plugin){
				push @parsed, '{{';
				push @parsed, $self->parse_line($source);
			} else {
				my $info = &Wiki::get_plugin_info($plugin->{command});
				if($info->{TYPE} eq "inline"){
					push @parsed, $self->plugin($plugin);
				} else {
					push @parsed, $self->parse_line("<<".$plugin->{command}."プラグインは存在しません。>>");
				}
				if ($source ne "") {
					$source = $plugin->{post};
				}
			}
		}

		# ページ別名リンク
		elsif ($source =~ /^\[\[([^\[]+?)\|([^\|\[]+?)\]\]/) {
			my $label = $1;
			my $page  = $2;
			$source = $';
			push @parsed, $self->wiki_anchor($page, $label);
		}

		# URL別名リンク
		elsif ($source
			=~ /^\[([^\[]+?)\|((?:http|https|ftp|mailto):[a-zA-Z0-9\.,%~^_+\-%\/\?\(\)!&=:;\*#\@'\$]*)\]/
			|| $source =~ /^\[([^\[]+?)\|(file:[^\[\]]*)\]/
			|| $source
			=~ /^\[([^\[]+?)\|((?:\/|\.\/|\.\.\/)+[a-zA-Z0-9\.,%~^_+\-%\/\?\(\)!&=:;\*#\@'\$]*)\]/
			)
		{
			my $label = $1;
			my $url   = $2;
			$source = $';
			if (   index($url, q{"}) >= 0
				|| index($url, '><') >= 0
				|| index($url, 'javascript:') >= 0)
			{
				push @parsed, $self->parse_line('<<不正なリンクです。>>');
			}
			else {
				push @parsed, $self->url_anchor($url, $label);
			}
		}

		# URLリンク
		elsif ($source
			=~ /^(?:https?|ftp|mailto):[a-zA-Z0-9\.,%~^_+\-%\/\?\(\)!&=:;\*#\@'\$]*/
			|| $source =~ /^file:[^\[\]]*/)
		{
			my $url = $&;
			$source = $';
			if (   index($url, q{"}) >= 0
				|| index($url, '><') >= 0
				|| index($url, 'javascript:') >= 0)
			{
				push @parsed, $self->parse_line('<<不正なリンクです。>>');
			}
			else {
				push @parsed, $self->url_anchor($url);
			}
		}

		# ページリンク
		elsif ($source =~ /^\[\[([^\|]+?)\]\]/) {
			my $page = $1;
			$source = $';
			push @parsed, $self->wiki_anchor($page);
		}

		# 任意のURLリンク
		elsif ($source =~ /^\[([^\[]+?)\|(.+?)\]/) {
			my $label = $1;
			my $url   = $2;
			$source = $';
			if (   index($url, q{"}) >= 0
				|| index($url, '><') >= 0
				|| index($url, 'javascript:') >= 0)
			{
				push @parsed, $self->parse_line('<<不正なリンクです。>>');
			}
			else {
				# URIを作成
				my $uri  = &main::MyBaseUrl().$ENV{"PATH_INFO"};
				push @parsed, $self->url_anchor($uri . '/../' . $url, $label);
			}
		}

		# ボールド、イタリック、取り消し線、下線
		elsif ($source =~ /^('''?|==|__)(.+?)\1/) {
			my $type  = $1;
			my $label = $2;
			$source = $';
			if ($type eq q{'''}) {
				push @parsed, $self->bold($label);
			}
			elsif ($type eq q{__}) {
				push @parsed, $self->underline($label);
			}
			elsif ($type eq q{''}) {
				push @parsed, $self->italic($label);
			}
			else {							   ## elsif ($type eq q{==}) {
				push @parsed, $self->denialline($label);
			}
		}

		# エラーメッセージ
		elsif ($source =~ /^<<(.+?)>>/) {
			my $label = $1;
			$source = $';
			push @parsed, $self->error($label);
		}

		# インライン Wiki 書式全体には macth しなかったとき
		else {
			# 1 文字進む。
			if ($source =~ /^(.)/) {
				$pre .= $1;
				$source = $';
			}
			
			# parse 結果を @array に保存する処理を飛ばして繰り返し。
			next SOURCE;
		}

		# インライン Wiki 書式全体に macth した後の
		# parse 結果を @array に保存する処理。

		# もし $pre が溜まっているなら、WikiNameの処理を実施。
		if ($pre ne q{}) {
			push @array, $self->_parse_line_wikiname($pre);
			$pre = q{};
		}

		push @array, @parsed;
	}

	# もし $pre が溜まっているなら、WikiNameの処理を実施。
	if ($pre ne q{}) {
		push @array, $self->_parse_line_wikiname($pre);
	}

	return @array;
}

#========================================================================
# parse_line() から呼び出され、WikiNameの検索・置換処理を行います。
#========================================================================
sub _parse_line_wikiname {
	my $self   = shift;
	my $source = shift;

	return () if (not defined $source);

	my @array = ();

	# $source が空になるまで繰り返す。
	while ($source ne q{}) {

		# WikiName
		if ($main::WIKI_NAME == 1 && $source =~ /[A-Z]+?[a-z]+?(?:[A-Z]+?[a-z]+)+/) {
			my $pre  = $`;
			my $page = $&;
			$source  = $';
			if ($pre ne q{}) {
				push @array, $self->_parse_line_wikiname($pre);
			}
			push @array, $self->wiki_anchor($page);
		}

		# WikiName も見つからなかったとき
		else {
			push @array, $self->text($source);
			return @array;
		}
	}
	return @array;
}

#===============================================================================
# <p>
# パースを開始前に呼び出されます。
# サブクラスで必要な処理がある場合はオーバーライドしてください。
# </p>
#===============================================================================
sub start_parse {}

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
	
	if($self->{list} == 1 && $level <= $self->{level}){
		$self->end_list;
	}
	$self->{list} = 0;
	
	$self->end_verbatim;
	$self->end_table;
	$self->end_quote;
	
	my $html = join("",@$obj);

	if($level > $self->{level}){
		while($level != $self->{level}){
			$self->{html} .= "<ul>\n";
			push(@{$self->{close_list}},"</ul>\n");
			$self->{level}++;
		}
	} elsif($level <= $self->{level}){
		while($level-1 != $self->{level}){
			if($self->{'list_close_'.$self->{level}} == 1){
				$self->{html} .= "</li>\n";
				$self->{'list_close_'.$self->{level}} = 0;
			}
			if($level == $self->{level}){
				last;
			}
			$self->{html} .= pop(@{$self->{close_list}});
			$self->{level}--;
		}
	}
	
	$self->{html} .= "<li>".$html;
	$self->{'list_close_'.$level} = 1;
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
	
	if($self->{list} == 0 && $level <= $self->{level}){
		$self->end_list;
	}
	$self->{list} = 1;
	
	$self->end_verbatim;
	$self->end_table;
	$self->end_quote;
	
	my $html = join("",@$obj);
	
	if($level > $self->{level}){
		while($level != $self->{level}){
			$self->{html} .= "<ol>\n";
			push(@{$self->{close_list}},"</ol>\n");
			$self->{level}++;
		}
	} elsif($level <= $self->{level}){
		while($level-1 != $self->{level}){
			if($self->{'list_close_'.$self->{level}} == 1){
				$self->{html} .= "</li>\n";
				$self->{'list_close_'.$self->{level}} = 0;
			}
			if($level == $self->{level}){
				last;
			}
			$self->{html} .= pop(@{$self->{close_list}});
			$self->{level}--;
		}
	}
	
	$self->{html} .= "<li>".$html;
	$self->{'list_close_'.$level} = 1;
}

#==============================================================================
# リストの終了
#==============================================================================
sub end_list {
	my $self  = shift;
	while($self->{level} != 0){
		if($self->{'list_close_'.($self->{level})} == 1){
			$self->{html} .= "</li>\n";
			$self->{'list_close_'.$self->{level}} = 0;
		}
		$self->{html} .= pop(@{$self->{close_list}});
		$self->{level}--;
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
	
	my $html  = join("",@$obj);
	
	# メインの表示領域でないとき
	if(!$self->{main}){
		$self->{html} .= "<h".($level+1).">".$html."</h".($level+1).">\n";

	# メインの表示領域の場合はアンカを出力
	} else {
		if($level==2){
			$self->{html} .= "<h".($level+1)."><a name=\"p".$self->{p_cnt}."\"><span class=\"sanchor\">&nbsp;</span>".
			                 $html."</a></h".($level+1).">\n";
		} else {
			$self->{html} .= "<h".($level+1)."><a name=\"p".$self->{p_cnt}."\">".$html."</a></h".($level+1).">\n";
		}
	}
	$self->{p_cnt}++;
}

#==============================================================================
# 水平線
#==============================================================================
sub l_line {
	my $self = shift;
	
	if($self->{para}==1){
		$self->{html} .= "</p>\n";
		$self->{para} = 0;
	}
	
	$self->end_list;
	$self->end_verbatim;
	$self->end_table;
	$self->end_quote;
	
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
	
	if($self->{para}==1){
		$self->{html} .= "</p>\n";
		$self->{para} = 0;
	} elsif($main::BR_MODE==1){
		$self->{html} .= "<br>\n";
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
	
	$text =~ s/^\s//;
	$self->{pre} .= Util::escapeHTML($text)."\n";
}

sub end_verbatim {
	my $self  = shift;
	if($self->{pre} ne ""){
		$self->{html} .= "<pre>".$self->{pre}."</pre>\n";
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
	
	my $tag = "td";
	
	if($self->{table}==0){
		$self->{table}=1;
		$self->{html} .= "<table>\n";
		$tag = "th";
	} else {
		$self->{table}=2;
	}
	
	my @columns = ();
	foreach(@$row){
		my $html = join("",@$_);
		if($#columns != -1 && $html eq '&lt;&lt;'){
			@columns[$#columns]->{colspan}++;
		} else {
			push(@columns, {colspan => 1, html => $html});
		}
	}
	$self->{html} .= "<tr>\n";
	foreach(@columns){
		$self->{html} .= "<$tag colspan=\"".$_->{colspan}."\">".$_->{html}."</$tag>\n";
	}
	$self->{html} .= "</tr>\n";
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
	my $html = join("",@$obj);
	
	if($self->{para}==0){
		$self->{html} .= "<p>";
		$self->{para} = 1;
	}
	$self->{html} .= $html;
	
	# brモードに設定されている場合は<br>を足す
	if($main::BR_MODE==1){
		$self->{html} .= "<br>\n";
	}
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
	
	$self->end_list;
	$self->end_verbatim;
	$self->end_table;
	$self->end_quote;
	
	my $html1 = join("",@$obj1);
	my $html2 = join("",@$obj2);
	
	$self->{html} .= "<dl>\n<dt>".$html1."</dt>\n<dd>".$html2."</dd>\n</dl>\n";
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
	
	if($url eq $name && $url=~/\.(gif|jpg|jpeg|bmp|png)$/i && $main::DISPLAY_IMAGE==1){
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
	
	my $anchor = undef;
	my $ppage = $page;
	
	if(!defined($name) || $name eq ""){
		$name = $page;
	}
	
	if(&Wiki::page_exists($page)){
		#アンカーを含むページが存在する場合はリンクを優先
		return "<a href=\"".&Wiki::create_page_url($page)."\" class=\"wikipage\">".
		       &Util::escapeHTML($name)."</a>";
	} else {
		#最後の"#"以降をアンカーとする
		if($page =~ m/#([^#]+)$/) {
			$page = $`;
			$anchor = $1;
		}
		if(defined($anchor) && $page eq '') {
			#同一ページのアンカーリンク
			return "<a href=\"#$anchor\" class=\"wikipage\">".
			       &Util::escapeHTML($name)."</a>";
		} elsif(&Wiki::page_exists($page)) {
			#指定ページのアンカーリンク
			return "<a href=\"".&Wiki::create_page_url($page).(defined($anchor)?"#".$anchor:"")."\" class=\"wikipage\">".
			       &Util::escapeHTML($name)."</a>";
		} else {
			#新規ページ作成用リンク
			return "<span class=\"nopage\">".&Util::escapeHTML($name)."</span>".
			       "<a href=\"".&Wiki::create_page_url($page)."\">?</a>";
		}
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
	
	my $func_ref = &Wiki::get_plugin_info($plugin->{command})->{FUNCTION};
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
	
	my $func_ref = &Wiki::get_plugin_info($plugin->{command})->{FUNCTION};
	my $result = &$func_ref(@{$plugin->{args}});
	if(defined($result) && $result ne ""){
		$self->{html} .= $result;
	}
}

#==============================================================================
# イメージ
#==============================================================================
sub l_image {
	my $self   = shift;
	my $page   = shift;
	my $file   = shift;
	my $width  = shift;
	my $height = shift;
	
	if($self->{para}==1){
		$self->{html} .= "</p>\n";
		$self->{para} = 0;
	}
	
	$self->end_list;
	$self->end_verbatim;
	$self->end_table;
	$self->end_quote;
	
	$self->{html} .= "<div class=\"image\">";
	$self->{html} .= "<img src=\"".&Wiki::create_url({'p'=>$page,'f'=>$file},$main::DOWNLOAD_SCRIPT)."\"";
	$self->{html} .= " width=\"$width\"" if ($width ne "");
	$self->{html} .= " height=\"$height\"" if ($height ne "");
	$self->{html} .= "/>";
	$self->{html} .= "</div>\n";
}

#==============================================================================
# エラーメッセージ
#==============================================================================
sub error {
	my $self  = shift;
	my $label = shift;
	
	return "<span class=\"error\">".Util::escapeHTML($label)."</span>";
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
	&jcode::convert(\$retstr,"euc");
	
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
	&jcode::convert(\$retstr,"euc");
	
	my %table = (
		'&' => '&amp;',
		'"' => '&quot;',
		'<' => '&lt;',
		'>' => '&gt;',
	);
	$retstr =~ s/([&\"<>])/$table{$1}/go;
	$retstr =~ s/&amp;#([0-9]{1,5});/&#$1;/go;
	$retstr =~ s/&#(0*(0|9|10|13|38|60|62));/&amp;#$1;/g;
#	$retstr =~ s/&amp;([a-zA-Z0-9]{2,8});/&$1;/go;
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
# ページ名が使用可能かどうかチェックします。
#===============================================================================
sub check_pagename {
	my $pagename = shift;

	#ページ名をチェック
	if( !defined($pagename)
		|| $pagename eq ""                     # 空
		|| $pagename =~ /[\|\[\]]/             # |[]
		|| $pagename =~ /^:/                   # コロンで始まる
		|| $pagename =~ /[^:]:[^:]/            # コロン単体での使用
		|| $pagename =~ /^\s+$/                # 空白のみ
	){
		return 0;
	}
	return 1;
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

#==============================================================================
# メール送信
#==============================================================================
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
	if($ua=~/^DoCoMo\// || $ua=~ /^J-PHONE\// || $ua=~ /UP\.Browser/ || $ua=~ /\(DDIPOCKET\;/ || $ua=~ /\(WILLCOM\;/ || $ua=~ /^Vodafone\// || $ua=~ /^SoftBank\//){
		return 1;
	} else {
		return 0;
	}
}

#===============================================================================
# スマートフォンかどうかチェックします。
#===============================================================================
sub smartphone {
	my $ua = $ENV{'HTTP_USER_AGENT'};
	if(!defined($ua)){
		return 0;
	}
	if($ua =~ /Android/ || $ua =~ /iPhone/){
		return 1;
	} else {
		return 0;
	}
}

1;
