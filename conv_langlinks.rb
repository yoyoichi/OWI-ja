# coding: utf-8
#
#  conv_langlinks.rb  -- a converter to get English names from langlinks file (SQL)
#
# Copyright (c) 2014 Yoichi Yokogawa
#
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php

if RUBY_VERSION.to_f < 2.1
  require 'string-scrub'
end


begin
  filename = ARGV.first

  hash_count = {}
  hash_en = {}
  open(filename, 'r:UTF-8') do |f|
    f.each_line do |line|
      line = line.chomp.scrub

      line.scan(/\((\d+)\,\'(.+?)\'\,\'(.+?)\'/) do |s|
        id = $1.to_i
        lang = $2
        str = $3
	next  if str =~ /^(User|Wikipedia|Template)\:/i
        if hash_count[id] == nil
          hash_count[id] = 1
        else
          hash_count[id] += 1
        end
        if lang == 'en'
          hash_en[id] = str
        end
      end
    end
  end

  hash_en.keys.sort.each do |id|
    next  if hash_count[id] < 3
    print id, "\t", hash_count[id], "\t", hash_en[id], "\n"
  end
end
