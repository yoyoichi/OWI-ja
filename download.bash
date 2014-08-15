#!/bin/bash -eu
curl -O http://dumps.wikimedia.org/jawiki/latest/jawiki-latest-langlinks.sql.gz
gunzip -f jawiki-latest-langlinks.sql.gz
curl -O http://dumps.wikimedia.org/jawiki/latest/jawiki-latest-pages-articles.xml.bz2
bunzip2 -f jawiki-latest-pages-articles.xml.bz2
