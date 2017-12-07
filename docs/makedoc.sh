#!/bin/sh
# HTMLファイルに変換
perl ../../tools/wiki2html.pl "http://fswiki.poi.jp/wiki.cgi/docs?action=SOURCE&page=FSWikiLite%2Freadme" -css=default.css -title=README > readme.html
perl ../../tools/wiki2html.pl "http://fswiki.poi.jp/wiki.cgi/docs?action=SOURCE&page=FSWikiLite%2F%A5%D7%A5%E9%A5%B0%A5%A4%A5%F3%B3%AB%C8%AF" -css=default.css -title=プラグイン開発 > plugindev.html
