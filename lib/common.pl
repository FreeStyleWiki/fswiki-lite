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
	print "    <a href=\"".&Wiki::create_url({p=>"FrontPage"})."\">FrontPage</a>\n";
	print "    <a href=\"".&Wiki::create_url({a=>"new"})."\">����</a>\n";
	if($show==1){
		print "    <a href=\"".&Wiki::create_url({a=>"edit",p=>$in{"p"}})."\">�Խ�</a>\n";
	}
	print "    <a href=\"".&Wiki::create_url({a=>"search"})."\">����</a>\n";
	print "    <a href=\"".&Wiki::create_url({a=>"list"})."\">����</a>\n";
	print "    <a href=\"".&Wiki::create_url({p=>"Help"})."\">�إ��</a>\n";
	print "  </span>\n";
	print "</div>\n";
	
	print "<h1>".&Util::escapeHTML($title)."</h1>\n";
	if(&Wiki::page_exists("Menu")){
		print "<div class=\"main\">\n";
	}
}

#-------------------------------------------------------------------------------
# �եå���ɽ��
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
# ��Ver(0.0.11)�ߴ����ݻ�
# �����С������Ǻ������ޤ���
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
# Wiki��Ϣ�δؿ����󶡤���ѥå�����
#
###############################################################################
package Wiki;

local @current_parser = [];

#==============================================================================
# �ץ饰����ξ����������ޤ�
#==============================================================================
sub get_plugin_info {
	my $name = shift;
	return defined($main::P_PLUGIN->{$name}) ? {FUNCTION=>$main::P_PLUGIN->{$name}, TYPE=>'paragraph'} :
	       defined($main::I_PLUGIN->{$name}) ? {FUNCTION=>$main::I_PLUGIN->{$name}, TYPE=>'inline'   } :
	       defined($main::B_PLUGIN->{$name}) ? {FUNCTION=>$main::B_PLUGIN->{$name}, TYPE=>'block'    } :
	       {};
}

#==============================================================================
# Wiki���������Ϥ���HTML��������ޤ�
#==============================================================================
sub process_wiki {
	my $source  = shift;
	my $mainflg = shift;
	my $parser  = HTMLParser->new($mainflg);
	
	# ΢����(�ץ饰������������ѡ�����Ȥ����)
	push(@current_parser, $parser);
	
	$parser->parse($source);
	
	# �ѡ����λ��Ȥ����
	pop(@current_parser);
	
	return $parser->{html};
}

#==============================================================================
# �ѡ�����ξ�硢����ͭ����HTMLParser�Υ��󥹥��󥹤��ֵѤ��ޤ���
# �ѡ���������Ƥ�ץ饰���󤫤��ѹ����������˻��Ѥ��ޤ���
#==============================================================================
sub get_current_parser {
	return $current_parser[$#current_parser];
}

#===============================================================================
# ����饤��ץ饰�����ѡ������ƥ��ޥ�ɤȰ�����ʬ��
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
			return {error=>"����饤��ץ饰����ι�ʸ�������Ǥ���"};
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
# �ڡ���ɽ����URL������
#==============================================================================
sub create_page_url {
	my $page = shift;
	return create_url({p=>$page});
}

#==============================================================================
# Ǥ�դ�URL������
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
# �ڡ����ΰ��������
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
# �ڡ����ι������������
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
# �ڡ��������
#==============================================================================
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
#==============================================================================
# �ڡ�������¸
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
	
	&Util::send_mail($action,$page);
}

#==============================================================================
# �ڡ�����¸�ߤ��뤫�ɤ���
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
# �������Ϥ����ڡ���������
#==============================================================================
sub redirect {
	my $page = shift;
	my $url  = &Wiki::create_url({p=>$page});
	&redirectURL($url);
}

#==============================================================================
# �������Ϥ���URL������
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
# �ڡ�������
#==============================================================================
sub remove_page {
	my $page     = shift;
	my $enc_page = &Util::url_encode($page);
	unlink("$main::DATA_DIR/$enc_page.wiki") or &Util::error("$main::DATA_DIR/$enc_page.wiki�κ���˼��Ԥ��ޤ�����");
	
	&Util::send_mail('DELETE',$page);
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
# �ѡ���
#===============================================================================
sub parse {
	my $self   = shift;
	my $source = shift;
	
	$self->start_parse;
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
		if($line eq "" && !$self->{block}){
			$self->l_paragraph();
			next;
		}
		
		# �֥�å��񼰤Υ���������
		if(!$self->{block} && ($word2 eq "\\\\" || $word1 eq "\\")){
			my @obj = $self->parse_line(substr($line, 1));
			$self->l_text(\@obj);
			next;
		}
		
		# �ѥ饰��եץ饰����
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
	
	# �ѡ�����Υ֥�å��ץ饰���󤬤��ä���硢�Ȥꤢ����ɾ�����Ƥ�����
	if($self->{block}){
		my $plugin = $self->{block};
		delete($self->{block});
		$self->l_plugin($plugin);
	}
	
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
	my ($self, $source) = @_;

	return () if (not defined $source);

	my @array = ();
	my $pre   = q{};
	my @parsed = ();

	# $source �����ˤʤ�ޤǷ����֤���
	SOURCE:
	while ($source ne q{}) {

		# �ɤΥ���饤�� Wiki �񼰤���Ƭ�ˤ� match ���ʤ����
		if (!($source =~ /^(.*?)((?:\{\{|\[\[?|https?:|mailto:|f(?:tp:|ile:)|'''?|==|__|<<).*)$/)) {
			# WikiName�������ִ������Τ߼»ܤ��ƽ�λ����
			push @array, $self->_parse_line_wikiname($pre . $source);
			return @array;
		}

		$pre   .= $1;	# match ���ʤ��ä���Ƭ��ʬ��ί��Ƥ����Ƹ�ǽ�������
		$source = $2;	# match ��ʬ�ϸ�³�����ˤƾܺ٥����å���Ԥ�
		@parsed = ();

		# �ץ饰����
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
					push @parsed, $self->parse_line("<<".$plugin->{command}."�ץ饰�����¸�ߤ��ޤ���>>");
				}
				if ($source ne "") {
					$source = $plugin->{post};
				}
			}
		}

		# �ڡ�����̾���
		elsif ($source =~ /^\[\[([^\[]+?)\|([^\|\[]+?)\]\]/) {
			my $label = $1;
			my $page  = $2;
			$source = $';
			push @parsed, $self->wiki_anchor($page, $label);
		}

		# URL��̾���
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
				push @parsed, $self->parse_line('<<�����ʥ�󥯤Ǥ���>>');
			}
			else {
				push @parsed, $self->url_anchor($url, $label);
			}
		}

		# URL���
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
				push @parsed, $self->parse_line('<<�����ʥ�󥯤Ǥ���>>');
			}
			else {
				push @parsed, $self->url_anchor($url);
			}
		}

		# �ڡ������
		elsif ($source =~ /^\[\[([^\|]+?)\]\]/) {
			my $page = $1;
			$source = $';
			push @parsed, $self->wiki_anchor($page);
		}

		# Ǥ�դ�URL���
		elsif ($source =~ /^\[([^\[]+?)\|(.+?)\]/) {
			my $label = $1;
			my $url   = $2;
			$source = $';
			if (   index($url, q{"}) >= 0
				|| index($url, '><') >= 0
				|| index($url, 'javascript:') >= 0)
			{
				push @parsed, $self->parse_line('<<�����ʥ�󥯤Ǥ���>>');
			}
			else {
				# URI�����
				my $uri  = &main::MyBaseUrl().$ENV{"PATH_INFO"};
				push @parsed, $self->url_anchor($uri . '/../' . $url, $label);
			}
		}

		# �ܡ���ɡ�������å������ä���������
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

		# ���顼��å�����
		elsif ($source =~ /^<<(.+?)>>/) {
			my $label = $1;
			$source = $';
			push @parsed, $self->error($label);
		}

		# ����饤�� Wiki �����Τˤ� macth ���ʤ��ä��Ȥ�
		else {
			# 1 ʸ���ʤࡣ
			if ($source =~ /^(.)/) {
				$pre .= $1;
				$source = $';
			}
			
			# parse ��̤� @array ����¸������������Ф��Ʒ����֤���
			next SOURCE;
		}

		# ����饤�� Wiki �����Τ� macth �������
		# parse ��̤� @array ����¸���������

		# �⤷ $pre ��ί�ޤäƤ���ʤ顢WikiName�ν�����»ܡ�
		if ($pre ne q{}) {
			push @array, $self->_parse_line_wikiname($pre);
			$pre = q{};
		}

		push @array, @parsed;
	}

	# �⤷ $pre ��ί�ޤäƤ���ʤ顢WikiName�ν�����»ܡ�
	if ($pre ne q{}) {
		push @array, $self->_parse_line_wikiname($pre);
	}

	return @array;
}

#========================================================================
# parse_line() ����ƤӽФ��졢WikiName�θ������ִ�������Ԥ��ޤ���
#========================================================================
sub _parse_line_wikiname {
	my $self   = shift;
	my $source = shift;

	return () if (not defined $source);

	my @array = ();

	# $source �����ˤʤ�ޤǷ����֤���
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

		# WikiName �⸫�Ĥ���ʤ��ä��Ȥ�
		else {
			push @array, $self->text($source);
			return @array;
		}
	}
	return @array;
}

#===============================================================================
# <p>
# �ѡ����򳫻����˸ƤӽФ���ޤ���
# ���֥��饹��ɬ�פʽ�����������ϥ����С��饤�ɤ��Ƥ���������
# </p>
#===============================================================================
sub start_parse {}

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
# �ꥹ�Ȥν�λ
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
	
	my $html  = join("",@$obj);
	
	# �ᥤ���ɽ���ΰ�Ǥʤ��Ȥ�
	if(!$self->{main}){
		$self->{html} .= "<h".($level+1).">".$html."</h".($level+1).">\n";

	# �ᥤ���ɽ���ΰ�ξ��ϥ��󥫤����
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
# ��ʿ��
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
# ������ڤ�
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
# �ơ��֥�
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
# �ѡ�����λ���ν���
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
# �Խ񼰤˳������ʤ���
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
	
	# br�⡼�ɤ����ꤵ��Ƥ������<br>��­��
	if($main::BR_MODE==1){
		$self->{html} .= "<br>\n";
	}
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
	
	$self->end_list;
	$self->end_verbatim;
	$self->end_table;
	$self->end_quote;
	
	my $html1 = join("",@$obj1);
	my $html2 = join("",@$obj2);
	
	$self->{html} .= "<dl>\n<dt>".$html1."</dt>\n<dd>".$html2."</dd>\n</dl>\n";
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
	
	if($url eq $name && $url=~/\.(gif|jpg|jpeg|bmp|png)$/i && $main::DISPLAY_IMAGE==1){
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
	
	my $anchor = undef;
	my $ppage = $page;
	
	if(!defined($name) || $name eq ""){
		$name = $page;
	}
	
	if(&Wiki::page_exists($page)){
		#���󥫡���ޤ�ڡ�����¸�ߤ�����ϥ�󥯤�ͥ��
		return "<a href=\"".&Wiki::create_page_url($page)."\" class=\"wikipage\">".
		       &Util::escapeHTML($name)."</a>";
	} else {
		#�Ǹ��"#"�ʹߤ򥢥󥫡��Ȥ���
		if($page =~ m/#([^#]+)$/) {
			$page = $`;
			$anchor = $1;
		}
		if(defined($anchor) && $page eq '') {
			#Ʊ��ڡ����Υ��󥫡����
			return "<a href=\"#$anchor\" class=\"wikipage\">".
			       &Util::escapeHTML($name)."</a>";
		} elsif(&Wiki::page_exists($page)) {
			#����ڡ����Υ��󥫡����
			return "<a href=\"".&Wiki::create_page_url($page).(defined($anchor)?"#".$anchor:"")."\" class=\"wikipage\">".
			       &Util::escapeHTML($name)."</a>";
		} else {
			#�����ڡ��������ѥ��
			return "<span class=\"nopage\">".&Util::escapeHTML($name)."</span>".
			       "<a href=\"".&Wiki::create_page_url($page)."\">?</a>";
		}
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
	
	my $func_ref = &Wiki::get_plugin_info($plugin->{command})->{FUNCTION};
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
	
	my $func_ref = &Wiki::get_plugin_info($plugin->{command})->{FUNCTION};
	my $result = &$func_ref(@{$plugin->{args}});
	if(defined($result) && $result ne ""){
		$self->{html} .= $result;
	}
}

#==============================================================================
# ���᡼��
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
# ���顼��å�����
#==============================================================================
sub error {
	my $self  = shift;
	my $label = shift;
	
	return "<span class=\"error\">".Util::escapeHTML($label)."</span>";
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
	&jcode::convert(\$retstr,"euc");
	
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
# �ڡ���̾�����Ѳ�ǽ���ɤ��������å����ޤ���
#===============================================================================
sub check_pagename {
	my $pagename = shift;

	#�ڡ���̾������å�
	if( !defined($pagename)
		|| $pagename eq ""                     # ��
		|| $pagename =~ /[\|\[\]]/             # |[]
		|| $pagename =~ /^:/                   # �����ǻϤޤ�
		|| $pagename =~ /[^:]:[^:]/            # �����ñ�ΤǤλ���
		|| $pagename =~ /^\s+$/                # ����Τ�
	){
		return 0;
	}
	return 1;
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

#==============================================================================
# �᡼������
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
	if($ua=~/^DoCoMo\// || $ua=~ /^J-PHONE\// || $ua=~ /UP\.Browser/ || $ua=~ /\(DDIPOCKET\;/ || $ua=~ /\(WILLCOM\;/ || $ua=~ /^Vodafone\// || $ua=~ /^SoftBank\//){
		return 1;
	} else {
		return 0;
	}
}

#===============================================================================
# ���ޡ��ȥե��󤫤ɤ��������å����ޤ���
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
