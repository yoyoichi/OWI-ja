#!/bin/bash -eu
ruby -w conv_langlinks.rb jawiki-latest-langlinks.sql > en_titles.txt
ruby -w page2yaml.rb jawiki-latest-pages-articles.xml > owija_latest.yaml
