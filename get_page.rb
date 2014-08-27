# coding: utf-8
# jawiki-latest-pages-articles.xmlファイルから、指定されたタイトル部分だけを取り出す
#
# Copyright (c) 2014 Yoichi Yokogawa
#
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php



begin
  page_name = ARGV.first

  open('jawiki-latest-pages-articles.xml', 'r:UTF-8') do |f|
    state = 'START'
    s = ''
    title = ''

    while line = f.gets
      line = line.chomp.encode('UTF-8', 'UTF-8', :invalid => :replace)

      state = 'PAGE'  if line.include?('<page>')

      case state
      when 'PAGE'
        if line =~ /\<title\>(.+?)\<\/title\>/
	  title = $1.gsub('&amp;', '&').gsub('&quot;', '"')
	  if title == page_name
	    state = 'HIT'
	    s = "  <page>\n" + line + "\n"
	  end
	end
      when 'HIT'
        if line.include?('</page>')
	  print s + line + "\n"
	  exit 0
	end

        s += line + "\n"
      end
    end
  end
end
