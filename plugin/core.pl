################################################################################
#
# �����ץ饰����μ���
#
################################################################################
package Wiki::Plugin;

BEGIN {
	# �ѥ饰��եץ饰����Υ���ȥ�
	$main::P_PLUGIN->{recent}        = \&Wiki::Plugin::recent;
	$main::P_PLUGIN->{recentdays}    = \&Wiki::Plugin::recentdays;
	$main::P_PLUGIN->{category_list} = \&Wiki::Plugin::category_list;
	$main::P_PLUGIN->{ref_image}     = \&Wiki::Plugin::ref_image;
	$main::P_PLUGIN->{ref_text}      = \&Wiki::Plugin::ref_text;
	$main::P_PLUGIN->{outline}       = \&Wiki::Plugin::outline;
	$main::P_PLUGIN->{search}        = \&Wiki::Plugin::search;
	
	# ����饤��ץ饰����Υ���ȥ�
	$main::I_PLUGIN->{category}     = \&Wiki::Plugin::category;
	$main::I_PLUGIN->{lastmodified} = \&Wiki::Plugin::lastmodified;
	$main::I_PLUGIN->{ref}          = \&Wiki::Plugin::ref;
}

#==============================================================================
# �ڡ����ΰ����򹹿��������ɽ������ץ饰����
#==============================================================================
sub recent {
	my $max = shift;
	$max = 0 if($max eq "");
	my $buf = "";
	
	my @pages = &Wiki::get_page_list();
	my $count = 0;
	
	$buf .= "<ul>\n";
	foreach my $page (@pages){
		$buf .= "<li><a href=\"$main::MAIN_SCRIPT?p=".&Util::url_encode($page->{NAME})."\">".
		        &Util::escapeHTML($page->{NAME})."</a></li>\n";
		$count++;
		last if($count==$max && $max!=0);
	}
	$buf .= "</ul>\n";
	
	return $buf;
}

#==============================================================================
# ���դ��Ȥ˹������줿�ڡ��������ɽ������ץ饰����
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
		
		$buf .= "<li><a href=\"$main::MAIN_SCRIPT?p=".&Util::url_encode($page->{NAME})."\">".
		        &Util::escapeHTML($page->{NAME})."</a></li>\n";
	}
	
	if($buf ne ""){
		$buf .= "</UL>\n";
	}
	
	return $buf;
}

#==============================================================================
# �ڡ����򥫥ƥ��饤�����뤿��Υץ饰����
#==============================================================================
sub category {
	my $category = shift;
	if($category eq ""){
		return "���ƥ��꤬���ꤵ��Ƥ��ޤ���";
	} else {
		return "[<a href=\"$main::CATEGORY_SCRIPT?c=".&Util::url_encode($category)."\">".
		       "���ƥ���:".&Util::escapeHTML($category)."</a>]";
	}
}

#=============================================================================
# �ڡ����κǽ�����������ɽ������ץ饰����
#=============================================================================
sub lastmodified {
	my $page = $main::in{"p"};
	if(&Wiki::exists_page($page)){
		return  "�ǽ��������֡�".&Util::format_date(&Wiki::get_last_modified($page));
	} else {
		return undef;
	}
}

#=============================================================================
# ���ƥ��ꤴ�ȤΥڡ���������ɽ������ץ饰����
#=============================================================================
sub category_list {
	my $category = shift;
	my $buf      = "";
	
	# ���ꤵ�줿���ƥ����ɽ��
	if($category ne ""){
		my @pages = &Wiki::get_page_list();
		$buf .= "<h2>".&Util::escapeHTML($category)."</h2>\n";
		$buf .= "<ul>\n";
		#foreach my $page (sort(@pages)){
		foreach my $page (sort {$a->{NAME} cmp $b->{NAME}} @pages){
			my $source = &Wiki::get_page($page->{NAME});
			foreach my $line (split(/\n/,$source)){
				# �����Ȥ������ѥƥ����Ȥξ������Ф�
				next if($line =~ /^(\t| |\/\/)/);
				
				# ���ƥ���˥ޥå�������ꥹ�ƥ���
				if($line =~ /{{category\s+$category}}/){
					$buf .= "<li><a href=\"$main::MAIN_SCRIPT?p=".&Util::url_encode($page->{NAME})."\">".
					        &Util::escapeHTML($page->{NAME})."</a></li>";
					last;
				}
			}
		}
		$buf .= "</ul>\n";
	
	# ���ƤΥ��ƥ����ɽ��
	} else {
		my $category = {};
		my @pages = &Wiki::get_page_list();
		
		foreach my $page (@pages){
			my $source = &Wiki::get_page($page->{NAME});
			foreach my $line (split(/\n/,$source)){
				# �����Ȥ������ѥƥ����Ȥξ������Ф�
				next if($line =~ /^(\t| |\/\/)/);
				
				# ���ƥ���˥ޥå�������ꥹ�ƥ���
				while($line =~ /{{category\s+(.+?)}}/g){
					$category->{$1}->{$page->{NAME}} = 1;
				}
			}
		}
		
		foreach my $name (sort(keys(%$category))){
			$buf .= "<h2>".&Util::escapeHTML($name)."</h2>\n";
			$buf .= "<ul>\n";
			foreach my $page (sort(keys(%{$category->{$name}}))){
				$buf .= "<li><a href=\"$main::MAIN_SCRIPT?p=".&Util::url_encode($page)."\">".
				      &Util::escapeHTML($page)."</a></li>\n";
			}
			$buf .= "</ul>\n";
		}
	}
	return $buf;
}

#=============================================================================
# ź�եե�����ؤΥ�󥯤�ɽ�����뤿��Υץ饰����
#=============================================================================
sub ref {
	my $page = $main::in{"p"};
	my $file = shift;
	
	if($file eq ""){
		return "�ե����뤬���ꤵ��Ƥ��ޤ���";
	}
	
	my $filename = sprintf("$main::ATTACH_DIR/%s.%s",
						   &Util::url_encode($page),&Util::url_encode($file));
	unless(-e $filename){
		return "�ե����뤬¸�ߤ��ޤ���";
	}
	
	return sprintf("<a href=\"$main::DOWNLOAD_SCRIPT?p=%s&f=%s\">%s</a>",
	               &Util::url_encode($page),&Util::url_encode($file),$file);
}

#=============================================================================
# ź�եե����������Ȥ���ɽ�����뤿��Υץ饰����
#=============================================================================
sub ref_image {
	my $page = $main::in{"p"};
	my $file = shift;
	
	if($file eq ""){
		return "�ե����뤬���ꤵ��Ƥ��ޤ���";
	}
	
	my $filename = sprintf("$main::ATTACH_DIR/%s.%s",
						   &Util::url_encode($page),&Util::url_encode($file));
	unless(-e $filename){
		return "<p>�ե����뤬¸�ߤ��ޤ���</p>\n";
	}
	
	return sprintf("<div><img src=\"$main::DOWNLOAD_SCRIPT?p=%s&f=%s\"></div>",
	               &Util::url_encode($page),&Util::url_encode($file));
}

#=============================================================================
# ź�եե����������Ȥ���ɽ�����뤿��Υץ饰����
#=============================================================================
sub ref_text {
	my $page = $main::in{"p"};
	my $file = shift;
	
	if($file eq ""){
		return "�ե����뤬���ꤵ��Ƥ��ޤ���";
	}
	
	my $filename = sprintf("$main::ATTACH_DIR/%s.%s",
						   &Util::url_encode($page),&Util::url_encode($file));
	unless(-e $filename){
		return "<p>�ե����뤬¸�ߤ��ޤ���</p>\n";
	}
	
	my $text = "";
	open(DATA,$filename);
	while(<DATA>){
		$text .= $_;
	}
	close(DATA);
	
	# ���ԥ����ɤ��Ѵ�
	$text =~ s/\r\n/\n/g;
	$text =~ s/\r/\n/g;
	# ʸ�������ɤ��Ѵ�
	&jcode::convert(\$text,"euc");
	
	# pre������Ĥ����ֵ�
	return "<pre>".&Util::escapeHTML($text)."</pre>\n";
}

#=============================================================================
# �����ȥ饤���ɽ�����뤿��Υץ饰����
# ���Ϥ����HTML�Ϥ���äȼ�ȴ���Ǥ���
#=============================================================================
sub outline {
	my $page   = $main::in{'p'};
	my $source = &Wiki::get_page($page);
	my $level  = 0;
	my $count  = 0;
	my $buf    = "";
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
			
			$buf .= "<li><a href=\"#p$count\">$section</a></li>\n";
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
# �����ե������ɽ�����뤿��Υץ饰����
#=============================================================================
sub search {
	return "<form action=\"$main::MAIN_SCRIPT\" method=\"GET\">\n".
	       "  ������� <input type=\"text\" name=\"w\" size=\"20\" value=\"".&Util::escapeHTML($main::in{'w'})."\">\n".
	       "  <input type=\"submit\" value=\" �� �� \">\n".
	       "  <input type=\"hidden\" name=\"a\" value=\"search\">\n".
	       "</form>\n";
}

1;
