# coding: utf-8
#
#  jawiki_xml2yaml.rb  -- create YAML-format data from wikipedia page data (XML format)
#
# Copyright (c) 2014 Yoichi Yokogawa
#
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php

require 'yaml'
if RUBY_VERSION.to_f < 2.1
  require 'string-scrub'
end
require 'nokogiri'
#require 'pry'


# 英語版タイトルの情報を取得する
def get_en_titles(filename)
  h = {}

  open(filename, 'r:UTF-8') do |f|
    while line = f.gets
      line.chomp!

      a = line.split("\t")
      h[a[0].to_i] = a[2]
    end
  end

  h
end


def conv_list_element(str)
  c = str.count('|')
  if c == 1
    str = str[0, str.index('|')]
  elsif c > 1
    str = nil
  end

  if str == nil or str == '' or str[0] == '#' or str =~ /^File\:/ or str =~ /^ファイル\:/ or str =~ /Image\:/ or str =~ /画像\:/ or str =~ /^Wikipedia\:/
    str = nil
  end

  str
end


# <page>～</page> 全体を読みとる
def parse_page(page_str)
  doc = Nokogiri::XML.parse(page_str)
#  pp doc
  y = {}
  y['title'] = doc.xpath('/page/title').first.text
  y['kind'] = 'LIST'  if y['title'] =~ /の一覧$/
  y['kind'] = 'CATEGORY'  if y['title'] =~ /^Category\:/
  y['id'] = doc.xpath('/page/id').first.text.to_i

  redirects = doc.xpath('/page/redirect')
  y['redirect'] = redirects.first['title']  unless redirects.empty?

  timestamp = doc.xpath('/page/revision/timestamp').first.text
  y['date'] = timestamp[0, 10]

  unless y['redirect']
    texts = doc.xpath('/page/revision/text')
    if texts.size < 1
    elsif texts.size > 1
    else
      y.merge!(parse_page_text(texts.first.text))
    end
  end

  y
end


# <page>の本文テキストを読みとる
def parse_page_text(text_str)
  y = {}
  categories = []
  links = []
  state = 'NORMAL'
  lc = 0

  text_str.each_line do |line|
    line.chomp!
    line = line.gsub(/\<\!\-\-.+?\-\-\>/, ' ')
    lc += 1

    case state
    when 'NORMAL'
      if line =~ /\<\!\-\-/
	line = $`
	state = 'COMMENT'
      end

      cat = check_category(line)
      categories << cat  if cat

      ret = check_birth_and_death(line)
      y.merge!(ret)  if ret

      y['kind'] = 'AIMAI'  if line =~ /\{\{aimai\}\}/i

      state = 'EXTERNAL_LINK'  if line =~ /\=\=\s*外部リンク\s*\=\=/

    when 'COMMENT'
      if line =~ /\-\-\>/
	state = 'NORMAL'
      end

    when 'EXTERNAL_LINK'
      link = check_external_link(line)
      links << link  if link

      state = 'NORMAL'  if line == ''
    end
  end

  y['links'] = links  if links.size > 0
  y['categories'] = categories  if categories.size > 0
  y['lines'] = lc
  y
end


# カテゴリー情報をチェックする
def check_category(line)
  ret = nil
  if line =~ /^\[\[Category\:(.+?)\]\]/i
    ret = $1
    if ret.include?('|')
      splitter_pos = ret.index('|')
      ret = ret[0, splitter_pos]
    end
  end

  ret
end


# 生年月日/没年月日をチェックする
def check_birth_and_death(line)
  ret = nil
  birth_date = nil
  death_date = nil

  if line =~ /^\|\s?(没年|没年月日|死亡日|died|death_date)\s*\=.+\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)/i
     year1 = $2
     month1 = $3
     month1 = '0' + month1  if month1.size == 1
     day1 = $4
     day1 = '0' + day1  if day1.size == 1
     year2 = $5
     month2 = $6
     month2 = '0' + month2  if month2.size == 1
     day2 = $7
     day2 = '0' + day2  if day2.size == 1
     if year1 < year2
       birth_date = year1 + '-' + month1 + '-' + day1
       death_date = year2 + '-' + month2 + '-' + day2
     else
       death_date = year1 + '-' + month1 + '-' + day1
       birth_date = year2 + '-' + month2 + '-' + day2
     end
   elsif line =~ /^\|\s?出生日\s*\=\s*(\d+)年(\d+)月(\d+)日/
     birth_year = $1
     birth_month = $2
     birth_month = '0' + birth_month  if birth_month.size == 1
     birth_day = $3
     birth_day = '0' + birth_day  if birth_day.size == 1
     birth_date = birth_year + '-' + birth_month + '-' + birth_day
  elsif line =~ /^\|\s?(誕生日|birth_date|生年)\s*\=\s*\{\{(生年月日と年齢|birth date and age).*?\|(\d+)\|(\d+)\|(\d+)/i
    birth_year = $3
    birth_month = $4
    birth_month = '0' + birth_month  if birth_month.size == 1
    birth_day = $5
    birth_day = '0' + birth_day  if birth_day.size == 1
    birth_date = birth_year + '-' + birth_month + '-' + birth_day
  end

  if birth_date or death_date
    ret = {}
    ret['birth_date'] = birth_date  if birth_date
    ret['death_date'] = death_date  if death_date
  end

  ret
end


# 外部リンクの情報をチェックする
def check_external_link(line)
  link = nil

  if line =~ /\[(https?\:\/\/.+?)\]/
    caption_pre = $`
    link = {}
    url = $1.gsub('　', ' ')
    caption = caption_pre.sub('*', '').strip
    pos = url.index(' ')
    if pos != nil
      link['url'] = url[0, pos]
      caption = url[pos + 1, 255]
    else
      link['url'] = url
    end
    pos2 = line.rindex(']', -1)
    if pos2 < line.size - 1
      caption_latter = line[pos2 + 1, 255].strip
      if caption_latter != ''
        caption += ' ' + caption_latter
      end
    end
    lang = ''
    caption = caption.gsub("''", '').gsub(/\{\{(\w{2}) icon\}\}/i) do
      lang += $1.downcase + ' '
      ''
    end
    lang = lang.strip
    link['caption'] = caption.strip
    link['lang'] = lang  if lang != '' and lang != 'ja'
  elsif line =~ /\{\{Official\s*\|(.+?)\}\}/i
    elems = []
    str = $1.strip
    link = {}
    link['url'] = ''
    link['caption'] = ''
    link['kind'] = 'official'
    if str.include?('|')
      elems = str.split('|')
    else
      elems << str
    end
    elems.each do |elem|
      if elem =~ /^mobile\=/i
        # 当面、何もしない
      elsif elem =~ /^name\=/i
        link['caption'] = $'
      elsif elem =~ /^1\=/
        link['url'] = $'
      else
        if elem =~ /^https?\:\/\//
          tmp = elem
          url = tmp
          if tmp.include?(' ')
            splitter_pos = str.index(' ')
            url = tmp[0, splitter_pos]
            link['caption'] = tmp[splitter_pos + 1, tmp.size]
          end
          link['url'] = url
        else
          link['url'] = 'http://' + elem
        end
      end
    end
  elsif line =~ /\{\{Cite web\s*\|(.+?)\}\}/i
    str = $1.strip
    link = {}
    link['url'] = ''
    link['caption'] = ''
    link['kind'] = 'cite'
    if str =~ /url\s*\=\s*(.+?)(\s|\||$)/
      link['url'] = $1
    end
    if str =~ /title\s*\=\s*(.+?)(\s|\||$)/
      link['caption'] = $1
    end
  elsif line =~ /\{\{Twitter\|(.+?)\}\}/i
    str = $1
    twitter_id = ''
    caption = ''
    if str.include?('|')
      splitter_pos = str.index('|')
      twitter_id = str[0, splitter_pos]
      caption = str[splitter_pos + 1, str.size]
    else
      twitter_id = str
      caption = str
    end
    link = {}
    link['url'] = 'https://twitter.com/' + twitter_id
    link['caption'] = caption
    link['kind'] = 'twitter'
  elsif line =~ /\{\{Facebook\|(.+?)\}\}/i
    str = $1
    facebook_id = ''
    caption = ''
    if str.include?('|')
      splitter_pos = str.index('|')
      facebook_id = str[0, splitter_pos]
      caption = str[splitter_pos + 1, str.size]
    else
      facebook_id = str
      caption = str
    end
    link = {}
    link['url'] = 'https://www.facebook.com/' + facebook_id
    link['caption'] = caption
    link['kind'] = 'facebook'
  elsif line =~ /\{\{allcinema name\|(.+?)\}\}/i
    str = $1
    allcinema_name_id = ''
    caption = ''
    if str.include?('|')
      splitter_pos = str.index('|')
      allcinema_name_id = str[0, splitter_pos]
      caption = str[splitter_pos + 1, str.size]
    else
      allcinema_name_id = str
    end
    link = {}
    link['url'] = 'http://www.allcinema.net/prog/show_p.php?num_p=' + allcinema_name_id
    link['caption'] = caption
    link['kind'] = 'allcinema name'
  end

  link = nil  if link and (link['url'] == nil or link['url'] == '')
  link
end



def page_to_record?(page_hash)
  title = page_hash['title']
  return false  if title =~ /^(Help|MediaWiki|Portal|Template|Wikipedia|ファイル|プロジェクト)\:/ or title =~ /^Category.+テンプレート$/

  true
end


begin
  filename = ARGV.first

  t1 = Time.now
  en_titles = get_en_titles('en_titles.txt')

  num_page_all = 0
  num_page_record = 0

  open(filename, 'r:UTF-8') do |f|
    page_xml = nil
    page_hash = nil

    while line = f.gets
      line = line.scrub.gsub(/\<\!\-\-.+?\-\-\>/, '')

      if line.include?('<page>')
        page_xml = line
      elsif line.include?('</page>')
        page_xml += line
        num_page_all += 1
        page_hash = parse_page(page_xml)
        en_title = en_titles[page_hash['id']]
        page_hash['title_en'] = en_title  if en_title
        if page_to_record?(page_hash)
          print page_hash.to_yaml
          num_page_record += 1
        end

        page_xml = nil
        page_hash = nil
      elsif page_xml
        page_xml += line
      end
    end
  end

  t2 = Time.now
  STDERR.print num_page_record, '  (', num_page_all, ")\n"
  STDERR.printf("elapsed time: %.1f\n", t2 - t1)
end


=begin
      when 'REVISION'
        next  if line.include?('<comment>')

        elsif line =~ /\[\[Category\:(.+?)\]\]/i
          category = CGI.unescape($1)
          pos = category.index('|')
          category = category[0, pos]  if pos
          categories << category
        end

        if line =~ /^\*.*?\[\[(.+?)\]\]/
          s = conv_list_element($1)
          list_elements << s  if s and not list_elements.include?(s)
        elsif line =~ /^\{\{see\|(.+?)\}\}/i
          s = conv_list_element($1)
          list_elements << s  if s and not list_elements.include?(s)
        elsif line =~ /^\|.*?\[\[(.+?)\]\]/
          s = conv_list_element($1)
          list_elements << s  if s and not list_elements.include?(s)
        end

        if line =~ /^\|\s?(没年|没年月日|死亡日|died|death_date)\s*\=.+\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)/i
          year1 = $2
          month1 = $3
          month1 = '0' + month1  if month1.size == 1
          day1 = $4
          day1 = '0' + day1  if day1.size == 1
          year2 = $5
          month2 = $6
          month2 = '0' + month2  if month2.size == 1
          day2 = $7
          day2 = '0' + day2  if day2.size == 1
          if year1 < year2
            birth_date = year1 + '-' + month1 + '-' + day1
            death_date = year2 + '-' + month2 + '-' + day2
          else
            death_date = year1 + '-' + month1 + '-' + day1
            birth_date = year2 + '-' + month2 + '-' + day2
          end
        elsif line =~ /^\|\s?出生日\s*\=\s*(\d+)年(\d+)月(\d+)日/
          birth_year = $1
          birth_month = $2
          birth_month = '0' + birth_month  if birth_month.size == 1
          birth_day = $3
          birth_day = '0' + birth_day  if birth_day.size == 1
          birth_date = birth_year + '-' + birth_month + '-' + birth_day
        elsif line =~ /^\|\s?(誕生日|birth_date|生年)\s*\=\s*\{\{(生年月日と年齢|birth date and age).*?\|(\d+)\|(\d+)\|(\d+)/i
          birth_year = $3
          birth_month = $4
          birth_month = '0' + birth_month  if birth_month.size == 1
          birth_day = $5
          birth_day = '0' + birth_day  if birth_day.size == 1
          birth_date = birth_year + '-' + birth_month + '-' + birth_day
        end
      when 'EXTERNAL_LINK'
        if line == ''
          state = 'REVISION'
        elsif line =~ /\[(https?\:\/\/.+?)\]/
          caption_pre = $`
          link_count += 1
          external_link = {}
          url = $1.gsub('&amp;', '&').gsub('&quot;', '"').gsub('　', ' ')
          caption = caption_pre.sub('*', '').strip
          pos = url.index(' ')
          if pos != nil
            external_link['url'] = url[0, pos]
            caption = url[pos + 1, 255]
          else
            external_link['url'] = url
          end
          pos2 = line.rindex(']', -1)
          if pos2 < line.size - 1
            caption_latter = line[pos2 + 1, 255].strip
            if caption_latter != ''
              caption += ' ' + caption_latter
            end
          end
	  lang = ''
          caption = CGI.unescape(caption).scrub.gsub("''", '').gsub(/\{\{(\w{2}) icon\}\}/i) do
	    lang += $1.downcase + ' '
	    ''
	  end
	  lang = lang.strip
          external_link['caption'] = caption
	  external_link['lang'] = lang  if lang != '' and lang != 'ja'
          external_links << external_link
        elsif line =~ /\{\{Official\|(.+?)\}\}/i
	  elems = []
	  str = $1
          external_link = {}
	  external_link['url'] = ''
	  external_link['caption'] = title
          external_link['kind'] = 'official'
	  if str.include?('|')
	    elems = str.split('|')
	  else
	    elems << str
	  end
	  elems.each do |elem|
	    if elem =~ /^mobile\=/i
              # 当面、何もしない
	    elsif elem =~ /^name\=/i 
	      external_link['caption'] = $'
	    elsif elem =~ /^1\=/
	      external_link['url'] = $'
	    else
	      if elem =~ /^https?\:\/\//
	        tmp = elem
		url = tmp
		if tmp.include?(' ')
	          splitter_pos = str.index(' ')
		  url = tmp[0, splitter_pos]
		  external_link['caption'] = tmp[splitter_pos + 1, tmp.size]
		end
	        external_link['url'] = url
	      else
		external_link['url'] = 'http://' + elem
	      end
	    end
	  end
          external_links << external_link
        elsif line =~ /\{\{Cite web\s*\|(.+?)\}\}/i
          str = $1
          external_link = {}
          external_link['url'] = ''
          external_link['caption'] = ''
          external_link['kind'] = 'cite'
          if str =~ /url\s*\=\s*(.+?)(\s|\||$)/
            external_link['url'] = $1
          end
          if str =~ /title\s*\=\s*(.+?)(\s|\||$)/
            external_link['caption'] = CGI.unescape($1)
          end
          external_links << external_link  if external_link['url'] != '' or external_link['caption'] != ''
        elsif line =~ /\{\{Twitter\|(.+?)\}\}/i
	  str = $1
	  twitter_id = ''
	  caption = ''
	  if str.include?('|')
	    splitter_pos = str.index('|')
	    twitter_id = str[0, splitter_pos]
	    caption = str[splitter_pos + 1, str.size]
	  else
	    twitter_id = str
	    caption = str
	  end
          external_link = {}
	  external_link['url'] = 'https://twitter.com/' + twitter_id
	  external_link['caption'] = caption
	  external_link['kind'] = 'twitter'
          external_links << external_link
        elsif line =~ /\{\{Facebook\|(.+?)\}\}/i
	  str = $1
	  facebook_id = ''
	  caption = ''
	  if str.include?('|')
	    splitter_pos = str.index('|')
	    facebook_id = str[0, splitter_pos]
	    caption = str[splitter_pos + 1, str.size]
	  else
	    facebook_id = str
	    caption = str
	  end
          external_link = {}
	  external_link['url'] = 'https://www.facebook.com/' + facebook_id
	  external_link['caption'] = caption
	  external_link['kind'] = 'facebook'
          external_links << external_link
        elsif line =~ /\{\{allcinema name\|(.+?)\}\}/i
	  str = $1
	  allcinema_name_id = ''
	  caption = ''
	  if str.include?('|')
	    splitter_pos = str.index('|')
	    allcinema_name_id = str[0, splitter_pos]
	    caption = str[splitter_pos + 1, str.size]
	  else
	    allcinema_name_id = str
	    caption = title
	  end
          external_link = {}
	  external_link['url'] = 'http://www.allcinema.net/prog/show_p.php?num_p=' + allcinema_name_id
	  external_link['caption'] = caption
	  external_link['kind'] = 'allcinema name'
          external_links << external_link
#        elsif line =~ /\{\{(.+?)\|(.+?)\|(.+?)\|(.+?)\}\}/
#          link_type = $1
#          link_subtype = $2
#          link_id = $3
#          link_caption = $4
#          external_link = {}
#          external_link['url'] = '@' + link_type + '|' + link_subtype + '|' + link_id
#          external_link['caption'] = link_caption + ' (' + link_subtype.capitalize + ')'
#          external_links << external_link
#        elsif line =~ /\{\{(.+?)\|(.+?)\|(.+?)\}\}/
#          link_type = $1
#          link_id = $2
#          link_caption = $3
#          external_link = {}
#          external_link['url'] = '@' + link_type + '|' + link_id
#          external_link['caption'] = link_caption + ' (' + link_type.capitalize + ')'
#          external_links << external_link
        end
      end

      kind = 'AIMAI'  if line =~ /\{\{aimai\}\}/i
      state = 'RELATED_ITEMS'  if line.include?('== 関連項目 ==') or line.include?('==関連項目==')
      state = 'EXTERNAL_LINK'  if line.include?('== 外部リンク ==') or line.include?('==外部リンク==')

      if line.include?('</page>')
        if id != '' and title != '' and update != ''
          if title !~ /^(Help|MediaWiki|Portal|Template|Wikipedia|ファイル|プロジェクト)\:/ and title !~ /^Category.+テンプレート$/
            y = {}  # YAML data
            y['id'] = id.to_i
            y['title'] = title
            y['title_en'] = title_en  if title_en != nil and title_en != ''
            y['kind'] = 'LIST'  if kind == 'LIST'
            y['kind'] = 'AIMAI'  if kind == 'AIMAI'
            y['update'] = update
            y['bytes'] = bytes
            y['link_count'] = link_count
            y['birth_date'] = birth_date  if birth_date
            y['death_date'] = death_date  if death_date
            y['redirect'] = redirect  if redirect
            if external_links.size > 0
              y['external_links'] = external_links
            end
            if categories.size > 0
              y['categories'] = categories
            end
            if (kind == 'LIST' or kind == 'AIMAI') and list_elements.size > 0
              y['list_elements'] = list_elements
            end
            print y.to_yaml
          end
          id = ''
          title = ''
          title_en = ''
          kind = ''
          update = ''
          redirect = nil
          link_count = 0
          birth_date = nil
          death_date = nil
          external_links = []
          categories = []
          list_elements = []
          infos = []
          bytes = 0
        end
      end
    end
  end
end
=end
