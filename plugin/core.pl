################################################################################
#
# コアプラグインの実装
#
################################################################################
package Wiki::Plugin;

BEGIN {
	# パラグラフプラグインのエントリ
	$main::P_PLUGIN->{recent}        = \&Wiki::Plugin::recent;
	$main::P_PLUGIN->{recentdays}    = \&Wiki::Plugin::recentdays;
	$main::P_PLUGIN->{category_list} = \&Wiki::Plugin::category_list;
	$main::P_PLUGIN->{ref_image}     = \&Wiki::Plugin::ref_image;
	$main::P_PLUGIN->{ref_text}      = \&Wiki::Plugin::ref_text;
	$main::P_PLUGIN->{outline}       = \&Wiki::Plugin::outline;
	$main::P_PLUGIN->{search}        = \&Wiki::Plugin::search;
	
	# インラインプラグインのエントリ
	$main::I_PLUGIN->{category}      = \&Wiki::Plugin::category;
	$main::I_PLUGIN->{lastmodified}  = \&Wiki::Plugin::lastmodified;
	$main::I_PLUGIN->{ref}           = \&Wiki::Plugin::ref;
	$main::I_PLUGIN->{raw}           = \&Wiki::Plugin::raw;
	
	# ブロックプラグインのエントリ
	$main::B_PLUGIN->{pre}           = \&Wiki::Plugin::pre;
	$main::B_PLUGIN->{bq}            = \&Wiki::Plugin::bq;
}

#==============================================================================
# ページの一覧を更新日時順に表示するプラグイン。
#==============================================================================
sub recent {
	my $max = shift;
	my $way = shift;
	
	# 表示方式を決定
	if($way eq ""){
		$way = "H";
	}
	if($max eq "V" || $max eq "v"){
		$way = "V";
		$max = 0;
	} elsif($max eq "H" || $max eq "h"){
		$way = "H";
		$max = 0;
	} elsif($max eq ""){
		$max = 0;
	}
	
	# 表示内容を作成
	my $buf = "";
	my $content = "";
	
	my @pages = &Wiki::get_page_list();
	my $count = 0;
	
	foreach my $page (@pages){
		$content = "<a href=\"".&Wiki::create_url({p=>$page->{NAME}})."\">".&Util::escapeHTML($page->{NAME})."</a>";
		if($way eq "H" || $way eq "h"){
			if($count!=0){
				$buf .= " / ";
			}
			$buf .= $content;
		} else {
			if($count==0){
				$buf .= "<ul>\n";
			}
			$buf .= "<li>".$content."</li>\n";
		}
		$count++;
		last if($count==$max && $max!=0);
	}
	if($count>0 && $way ne "H" && $way ne "h"){
		$buf .= "</ul>\n";
	}
	return $buf;
}

#==============================================================================
# 日付ごとに更新されたページを一覧表示するプラグイン。
#==============================================================================
sub recentdays {
	my $max = shift;
	$max = 5 if($max eq "");
	my $buf = "";
	
	my @pages = &Wiki::get_page_list();
	my $count = 0;
	
	my $last_year = 0;
	my $last_mon  = 0;
	my $last_day  = 0;
	
	foreach my $page (@pages){
		my ($sec, $min, $hour, $day, $mon, $year) = localtime($page->{TIME});
		
		$year += 1900;
		$mon  += 1;
		
		if($last_year!=$year || $last_mon!=$mon || $last_day!=$day){
			
			$count++;
			last if($count == $max+1);
			
			$last_year = $year;
			$last_mon  = $mon;
			$last_day  = $day;
			
			$buf .= "</ul>\n" if($buf ne "");
			$buf .= sprintf("<b>%04d/%02d/%02d</b>\n",$year,$mon,$day);
			$buf .= "<ul>\n";
		}
		
		$buf .= "<li><a href=\"".&Wiki::create_url({p=>$page->{NAME}})."\">".
		        &Util::escapeHTML($page->{NAME})."</a></li>\n";
	}
	
	if($buf ne ""){
		$buf .= "</UL>\n";
	}
	
	return $buf;
}

#==============================================================================
# ページをカテゴライズするためのプラグイン。
#==============================================================================
sub category {
	my $category = shift;
	if($category eq ""){
		return "<span class=\"error\">カテゴリが指定されていません。</span>";
	} else {
		return "[<a href=\"".&Wiki::create_url({c=>$category},$main::CATEGORY_SCRIPT)."\">".
		       "カテゴリ:".&Util::escapeHTML($category)."</a>]";
	}
}

#=============================================================================
# ページの最終更新日時を表示するプラグイン。
#=============================================================================
sub lastmodified {
	my $page = shift || $main::in{"p"};
	if(&Wiki::page_exists($page)){
		return  "最終更新時間：".&Util::format_date(&Wiki::get_last_modified($page));
	} else {
		return undef;
	}
}

#=============================================================================
# カテゴリごとのページ一覧を表示するプラグイン。
#=============================================================================
sub category_list {
	my $category = shift;
	my $buf      = "";
	
	# 指定されたカテゴリを表示
	if($category ne ""){
		my @pages = &Wiki::get_page_list();
		$buf .= "<h2>".&Util::escapeHTML($category)."</h2>\n";
		$buf .= "<ul>\n";
		#foreach my $page (sort(@pages)){
		foreach my $page (sort {$a->{NAME} cmp $b->{NAME}} @pages){
			my $source = &Wiki::get_page($page->{NAME});
			foreach my $line (split(/\n/,$source)){
				# コメントか整形済テキストの場合は飛ばす
				next if($line =~ /^(\t| |\/\/)/);
				
				# カテゴリにマッチしたらリスティング
				if($line =~ /{{category\s+$category}}/){
					$buf .= "<li><a href=\"".&Wiki::create_url({p=>$page->{NAME}})."\">".
					        &Util::escapeHTML($page->{NAME})."</a></li>";
					last;
				}
			}
		}
		$buf .= "</ul>\n";
	
	# 全てのカテゴリを表示
	} else {
		my $category = {};
		my @pages = &Wiki::get_page_list();
		
		foreach my $page (@pages){
			my $source = &Wiki::get_page($page->{NAME});
			foreach my $line (split(/\n/,$source)){
				# コメントか整形済テキストの場合は飛ばす
				next if($line =~ /^(\t| |\/\/)/);
				
				# カテゴリにマッチしたらリスティング
				while($line =~ /\{\{category\s+(.+?)\}\}/g){
					$category->{$1}->{$page->{NAME}} = 1;
				}
			}
		}
		
		foreach my $name (sort(keys(%$category))){
			$buf .= "<h2>".&Util::escapeHTML($name)."</h2>\n";
			$buf .= "<ul>\n";
			foreach my $page (sort(keys(%{$category->{$name}}))){
				$buf .= "<li><a href=\"".&Wiki::create_url({p=>$page})."\">".
				      &Util::escapeHTML($page)."</a></li>\n";
			}
			$buf .= "</ul>\n";
		}
	}
	return $buf;
}

#=============================================================================
# 添付ファイルへのリンクを表示するためのプラグイン。
#=============================================================================
sub ref {
	my $file  = shift;
	my $page  = shift;
	my $alias = shift;
	
	if($file eq ""){
		return "<p class=\"error\">ファイルが指定されていません。</p>\n";
	}
	if(!defined($page) || $page eq ""){
		$page = $main::in{"p"};
	}
	if(!defined($alias) || $alias eq ""){
		$alias = $file;
	}
	
	my $filename = sprintf("$main::ATTACH_DIR/%s.%s",
						   &Util::url_encode($page),&Util::url_encode($file));
	unless(-e $filename){
		return "<p class=\"error\">ファイルが存在しません。</p>\n";
	}
	
	return "<a href=\"".&Wiki::create_url({p=>$page,f=>$file},$main::DOWNLOAD_SCRIPT)."\">".&Util::escapeHTML($alias)."</a>";
}

#=============================================================================
# 添付ファイルを画像として表示するためのプラグイン。
#=============================================================================
sub ref_image {
	my $file    = shift;
	my $page = "";
	
	my @options = @_;
	my $width  = "";
	my $height = "";
	
	if($file eq ""){
		return "<p class=\"error\">ファイルが指定されていません。</p>\n";
	}
	foreach my $option (@options){
		if($option =~ /^w([0-9]+)$/){
			$width = $1;
		} elsif($option =~ /^h([0-9]+)$/){
			$height = $1;
		} else {
			$page = $option;
		}
	}
	if($page eq ""){
		$page = $main::in{"p"};
	}
	
	my $filename = sprintf("$main::ATTACH_DIR/%s.%s",
						   &Util::url_encode($page),&Util::url_encode($file));
	unless(-e $filename){
		return "<p class=\"error\">ファイルが存在しません。</p>\n";
	}
	
	&Wiki::get_current_parser()->l_image($page, $file, $width, $height);
	return undef;
}

#=============================================================================
# 添付ファイルを画像として表示するためのプラグイン。
#=============================================================================
sub ref_text {
	my $file = shift;
	my $page = shift || $main::in{"p"};
	
	if($file eq ""){
		return "<p class=\"error\">ファイルが指定されていません。</p>\n";
	}
	
	my $filename = sprintf("$main::ATTACH_DIR/%s.%s",
						   &Util::url_encode($page),&Util::url_encode($file));
	unless(-e $filename){
		return "<p class=\"error\">ファイルが存在しません。</p>\n";
	}
	
	my $text = "";
	open(DATA,$filename);
	while(<DATA>){
		$text .= $_;
	}
	close(DATA);
	
	# 改行コードを変換
	$text =~ s/\r\n/\n/g;
	$text =~ s/\r/\n/g;
	# 文字コードを変換
	&jcode::convert(\$text,"euc");
	
	# preタグをつけて返却
	return "<pre>".&Util::escapeHTML($text)."</pre>\n";
}

#=============================================================================
# アウトラインを表示するためのプラグイン
# 出力されるHTMLはちょっと手抜きです…
#=============================================================================
sub outline {
	my $page   = shift;
	my $url    = "";
	
	if (!defined($page)) {
		$page = $main::in{'p'};
	} else {
		$url  = &Wiki::create_url({p=>$page});
	}
	
	my $source = "";
	my $level  = 0;
	my $count  = 0;
	my $buf    = "";
	
	if(&Wiki::page_exists($page)){
		$source = &Wiki::get_page($page);
	}
	
	foreach my $line (split(/\n/,$source)){
		if($line=~/^(!{1,3})(.+)$/){
			my $find_level = 4 - length($1);
			
			while($level < $find_level){
				$buf .= "<ul>\n";
				$level++;
			}
			
			while($level > $find_level){
				$buf .= "</ul>\n";
				$level--;
			}
			my $section = &Util::delete_tag(&Wiki::process_wiki($2));
			
			$buf .= "<li><a href=\"".$url."#p$count\">$section</a></li>\n";
			$count++;
		}
	}
	while($level > 0){
		$buf .= "</ul>\n";
		$level--;
	}
	return $buf;
}

#=============================================================================
# 検索フォームを表示するためのプラグイン
#=============================================================================
sub search {
	my $way  = shift;
	my $or_checked = $main::in{'t'} eq 'or';
	my $with_content = $main::in{'c'} eq 'true';
	return "<form action=\"".&Wiki::create_url({},$main::MAIN_SCRIPT)."\" method=\"GET\">\n".
	       "  キーワード <input type=\"text\" name=\"w\" size=\"20\" value=\"".&Util::escapeHTML($main::in{'w'})."\">\n".
	       ($way eq "v" ? "<br>" : "").
	       "  <input type=\"radio\" name=\"t\" id=\"and\" value=\"and\"".(!$or_checked?" checked":"")."><label for=\"and\">AND</label>".
	       "  <input type=\"radio\" name=\"t\" id=\"or\" value=\"or\"".($or_checked?" checked":"")."><label for=\"or\">OR</label>".
	       ($way eq "v" ? "<br>" : "").
	       "  <input type=\"checkbox\" name=\"c\" id=\"contents\" value=\"true\"".($with_content?" checked":"")."><label for=\"contents\">ページ内容も含める</label>".
	       "  <input type=\"submit\" value=\" 検 索 \">\n".
	       "  <input type=\"hidden\" name=\"a\" value=\"search\">\n".
	       "</form>\n";
}

#=============================================================================
# 引数で指定した文字列をそのまま表示するインラインプラグイン
#=============================================================================
sub raw {
	my $text = shift;
	return &Util::escapeHTML($text);
}

#=============================================================================
# preタグを出力する複数行プラグイン
#=============================================================================
sub pre {
	my $text = shift;
	my $option = shift;
	
	my $count = 1;
	my $buf = "<pre>";
	my @lines = split(/\n/, $text);
	my $len = length($#lines + 1);
	foreach my $line (@lines){
		if($option eq "num"){
			$buf .= sprintf("%0${len}d", $count) . "|";
		}
		$buf .= Util::escapeHTML($line) . "\n";
		$count++;
	}
	
	return $buf . "</pre>";
}

#=============================================================================
# blockquoteタグを出力する複数行プラグイン
#=============================================================================
sub bq {
	my $text = shift;
	my $buf = "<blockquote>";
	foreach my $line (split(/(\r\n)|\n|\r/,&Util::escapeHTML($text))){
		$buf .= "<p>$line<p>";
	}
	$buf .= "</blockquote>";
	return $buf;
}

1;
