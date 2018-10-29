# encoding: UTF-8
require 'rubygems'
require 'mechanize'
require 'uri'

# ======================================================================
# NAME   : Mechanize(2.7.6) Test
# DATE   : 2018-10-30 06:54
# AUTHER : Create by PengMo.
# VERSION: 0.1
# DOCS   : http://mechanize.rubyforge.org/
# ======================================================================

STDOUT.sync = true

agent = Mechanize.new
page = agent.get('http://www.baidu.com/')
puts page.body
