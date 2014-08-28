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


  # 第2パス : カテゴリーやリダイレクトの情報を加える 
  open(filename, 'r:UTF-8') do |f|
    articles = []
    categories = []
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
          if y['redirect']
            article = Article.find(y['id'])
            redirect_article = Article.find_by(title: y['redirect'])
            if redirect_article
              article.redirect_article_id = redirect_article.id
              articles << article
            else
              print 'WARN: Redirect-to [', y['redirect'], '] does not exist.  (', y['title'], ")\n"
            end
          end

          if y['categories']
            child_article_id = y['id']
            y['categories'].each do |cat|
              cat_article = Article.find_by(title: 'Category:' + cat)
              if cat_article
                category = Category.new(article_id: cat_article.id, child_article_id: child_article_id)
                categories << category
              elsif cat != y['title']
		cat_article = Article.find_by(title: cat)
		if cat_article
		  category = Category.new(article_id: cat_article.id, child_article_id: child_article_id)
		else
                  print 'WARN: Category [', cat, '] does not exist.  (', y['title'], ")\n"
		end
              end
            end
          end


          if articles.size + categories.size >= 2000
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

              categories.each do |c|
                c.save
              end
            end
            print "Done.\n"

            articles = []
            categories = []
          end

          body = "---\n"
        else
          body += line + "\n"
        end
      end
    end

    if articles.size + categories.size > 0
      ActiveRecord::Base::transaction do
        articles.each do |a|
          a.save
        end

        categories.each do |c|
          c.save
        end
      end
    end
  end

end
