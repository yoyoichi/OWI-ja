# coding: utf-8
# migrationを使ってテーブルを作成する

require 'sqlite3'
require 'active_record'

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => 'owija.sqlite3'
)

class CreateArticleTable < ActiveRecord::Migration
  def up
    create_table :articles do |t|
      t.string :title, :null => false
      t.string :title_en
      t.string :kind
      t.integer :state, :default => 0, :null => false
      t.references :redirect_article
      t.integer :update_date, :null => false
      t.timestamps
    end

    add_index :articles, :title, :name => 'idx_articles_title', :unique => true
  end
end

=begin
class CreateSearchableTable < ActiveRecord::Migration
  def up
    create_table :searchables do |t|
      t.string :str, :null => false
    end
  end
end
=end


class CreateLinkTable < ActiveRecord::Migration
  def up
    create_table :links do |t|
      t.string :caption, :null => false
      t.string :url, :null => false
      t.string :kind
      t.string :lang
      t.references :article, :null => false
      t.integer :state, :default => 0, :null => false
    end

    add_index :links, :article_id, :name => 'idx_links_article_id'
  end
end


class CreateCategoryTable < ActiveRecord::Migration
  def up
    create_table :Categories do |t|
      t.references :article, :null => false
      t.integer :child_article_id, :null => false
    end

    add_index :categories, :article_id, :name => 'idx_categories_article_id'
  end
end


CreateArticleTable.new.up
#CreateSearchableTable.new.up
CreateLinkTable.new.up
CreateCategoryTable.new.up

:q
