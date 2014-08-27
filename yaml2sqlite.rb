# coding: utf-8
# YAML形式のデータをSQLite3のデータベースに保存する
require 'sqlite3'
require 'active_record'
require 'date'
require 'yaml'
require 'pp'

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => 'owija.sqlite3'
)


class Article < ActiveRecord::Base
  has_many :links
  has_many :categories
end


class Link < ActiveRecord::Base
  belongs_to :article
end


class Category < ActiveRecord::Base
  belongs_to :article
end


# 2001年1月1日を1日目とする数字に変換
def date2datenum(date_str)
  date = Date.iso8601(date_str)
  date.jd - 2451910
end


begin
  filename = ARGV.first
  state = 'START'
  body = ''
  open(filename, 'r:UTF-8') do |f|
    articles = []
    links = []
    f.each_line do |line|
      line.chomp!

      case state
      when 'START'
        if line == '---'
          state = 'BODY'
          body = "---\n"
	end

      when 'BODY'
        if line == '---'
          y = YAML.load(body)

#         print y['id'], ' ', y['title'], "\n"
          article = Article.new(:id => y['id'], :title => y['title'])
          article.update_date = date2datenum(y['date'])
	  if y['title_en'] != nil
	    article.title_en = y['title_en']
	  end
	  if y['kind'] != nil
	    article.kind = y['kind']
	  end
	  if y['links'] != nil
	    y['links'].each do |l|
	      caption = l['caption']
	      url = l['url']
	      if url.size > 255
	        print y['title'], "\t", url, "\n"
              end
	      kind = l['kind']
	      lang = l['lang']
              link = Link.new(:caption => caption, :url => url, :article_id => y['id'], :kind => kind, :lang => lang)
	      links << link  if url.size <= 255
	    end
	  end
	  articles << article

          if articles.size >= 1000
	    print "commit ... "
            ActiveRecord::Base::transaction do
	      articles.each do |a|
	        begin
	          a.save
		rescue
		  print 'ERR: ', y['title'], "\t", y['id'], "\n"
		  p $!
		end
	      end

	      links.each do |l|
	        l.save
              end
	    end
	    print "Done.\n"

	    articles = []
	    links = []
	  end

          body = "---\n"
        else
	  body += line + "\n"
	end
      end
    end

    if articles.size > 0
      ActiveRecord::Base::transaction do
        articles.each do |a|
          a.save
	end

	links.each do |l|
	  l.save
        end
      end
    end
  end


  # 第2パス : カテゴリーやリダイレクトの情報を加える 
end
