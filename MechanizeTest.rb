# encoding: UTF-8
require 'rubygems'
require 'mechanize'
require 'json'
require 'uri'

# ======================================================================
# NAME   : Mechanize(2.7.6) Test
# DATE   : 2018-10-30 06:54
# AUTHER : Create by PengMo.
# VERSION: 0.1
# DOCS   : https://www.rubydoc.info
# ======================================================================

STDOUT.sync = true

class NetRobot
	
	def initialize(proxy = "10.2.10.250", port = 808)
		@agent = Mechanize.new
		@agent.log = Logger.new "mech.log"
		@agent.user_agent_alias = 'Windows IE 11'
		@agent.default_encoding = 'utf-8'
		@base_url = ''
		#~ @@agent.set_proxy(proxy, port)
	end
	
	# --------------------------------------------------------------------------------
	# FUNC	: 获得 css
	# IN	: element 元素
    # OUT	: 元素的 css
    # DATE  : 2018.11.02 15:08
	# AUTHOR: Create by PengMo. 
	# --------------------------------------------------------------------------------
	def get_css(element)
		css = []
		while element != nil
			break if element.name == "document"
			css.insert(0, element.name)
			element = element.parent
		end
		return css.join(' > ')
	end
	
	# --------------------------------------------------------------------------------
	# FUNC	: 日期格式化14位
	# IN	: date 日期
    # OUT	: 格式化日期
    # DATE  : 2018.11.02 15:08
	# AUTH  : Create by PengMo. 
	# --------------------------------------------------------------------------------
	def format_date(date)
		if (date != "")
			begin
				date = Time.parse(date).strftime("%Y%m%d%H%M%S")
			rescue
				date = ""
			end
		end
		return date
	end
	
	# --------------------------------------------------------------------------------
	# FUNC	: 获得日期元素
	# IN	: element 元素
    # OUT	: 返回日期元素TEXT和格式化日期
    # DATE  : 2018.11.02 15:15
	# AUTHOR: Create by PengMo.
	# --------------------------------------------------------------------------------
	def get_date(element)
		for children in element.children
			text = children.text.gsub(/^\s+|\s+$/, '')
			if (text =~ /^\W*([0-9]+[年月日\-\/:]([0-9]+[年月日\-\/: ]*)+)\W*$/)
				return text, format_date($1)
			end
		end
		
		while element != nil
			break if element.name == "document"
			element = element.parent
			for children in element.children
				if (children.text != nil)
					text = children.text.gsub(/^\s+|\s+$/, '')
					if (text =~ /^\W*([0-9]+[年月日\-\/.:]([0-9]+[年月日\-\/.: ]*)+)\W*$/)
						return text, format_date($1)
					end
				end
			end
		end
		
		return "", ""
	end
	
	# --------------------------------------------------------------------------------
	# FUNC	: 获得翻页内容
	# IN	: page 当前页面
	# 		: page_num 页码
    # OUT	: 翻页后的 page
    # DATE  : 2018.11.02 15:13
	# AUTHOR: Create by PengMo.
	# --------------------------------------------------------------------------------
	def get_next_page(page, page_num)
		next_page_link = page.link_with(:text=>/^\W?#{page_num}\W?$/)
		
		if (next_page_link == nil)
			# 按页码翻页失败，查找下一页
			next_page_link = page.link_with(:text=>/下一页|下页/)
		end
		
		if (next_page_link == nil)
			return nil
		else
			return page = @agent.click(next_page_link)
		end
	end
	
	# --------------------------------------------------------------------------------
	# FUNC	: 获得页面
	# IN	: url 网址
    # OUT	: 返回网址的page页面
    # DATE  : 2018-11-02 15:11
	# AUTHOR: Create by PengMo.
	# --------------------------------------------------------------------------------
	def get_page(url)
		page = @agent.get(URI(url))

		# iframe 页面加载
		# page.encoding='utf-8'
		#~ http://xzsp.cangzhou.gov.cn/HBSC/Services/zwfwzx/a_list.jsp?key=018001001&page=1
		#~ page.css('iframe').each do |iframe|
			#~ puts url =  "http://#{page.uri.host}#{iframe['src']}"
			#~ cssList = get_links(@@agent.get(URI(url)), cssList)
		#~ end
		return page
	end
	
	# --------------------------------------------------------------------------------
	# FUNC	: 获得新闻列表内容
	# IN	: page 当前页面
	# 		: list_ignore_links 忽略连接
	# OUT	: 新闻列表内容，格式为  标题<##>发布时间<##>URL
    # DATE  : 2018-11-02 15:11
	# AUTHOR: Create by PengMo.
	# --------------------------------------------------------------------------------
	def get_list(page, list_ignore_links = {})
		
		begin
			if (page == nil)
				return []
			end
			cssList = {}
			
			page.css('a').each do |a|
				text = a['title'] != nil ? a['title'].strip : a.text.strip
				if (list_ignore_links.has_key?(text))
					next
				end
				css = get_css(a)
				if (cssList.has_key?(css))
					cssList[css].push(a)
				else
					cssList[css] = [a]
				end
			end
			
			cssList =  cssList.to_a.sort_by {|x| x[1].length}.reverse.first
			
			list = []
			
			if (cssList != nil)
				for item in cssList.last
					if (@base_url == '')
                        full_url =  @agent.click(item).uri.to_s
                        sub_url = item['href']
                        @base_url = full_url.sub(sub_url, '')
					end
					
					date, format_date = get_date(item)
					title = item['title'] != nil ? item['title'].strip : item.text.strip.sub(/#{date}.*/, '')
					next if title == ""
					url = "#{@base_url}#{item['href']}"
					list.push("#{title}<##>#{format_date}<##>#{url}")
				end
			end
			
			return list
		rescue => ex
			puts "【异常处理】#{ex.message}\n#{$@}-#{$!}"
			return ""
		end
	end
	
	# --------------------------------------------------------------------------------
	# FUNC	: 获得忽略连接
	# IN	: page 页面1
	# 		: page2 页面2
	# OUT	: 忽略连接原则是取两个页面中交集连接
    # DATE  : 2018-11-02 15:11
	# AUTHOR: Create by PengMo.
	# --------------------------------------------------------------------------------
	def get_ignore_links(page, page2)
		
		return {} if page == nil || page2 == nil
		
		page_links = {}
		page.links.each do |link|
			page_links[link.text.strip] = link.href
		end
		
		list_ignore_links = {}
		page2.links.each do |link|
			if (page_links.has_key?(link.text.strip))
				list_ignore_links[link.text.strip] = link.href
			end
		end
		
		return list_ignore_links
	end

=begin
	def url_rule(page_url_list)
		if (page_url_list.length < 4)
			return ''
		end
		
		info1 = page_url_list[1].strip.split(/([\/\.]+)/)
		info2 = page_url_list[2].strip.split(/([\/\.]+)/)
		info3 = page_url_list[3].strip.split(/([\/\.]+)/)

		url = ""
		for n in 0...info1.length
			if (info1[n] != "" && (info1[n] == info2[n] && info2[n] == info3[n]))
				url += info1[n]
			else
				if (info1[n] =~ /^[0-9]+$/ &&
					info2[n] =~ /^[0-9]+$/ &&
					info3[n] =~ /^[0-9]+$/)
					url += "{x}"
				else
					url = ''
					break
				end
			end
		end
		return url
	end

	# 查找制定日期的页面
	def goto_page(page_url_list, list_ignore_links, date = 201701)
		url_rule = url_rule(page_url_list)
		return nil if (url_rule == "")

		list = 1..2000
		list = list.to_a
		mid = 0
		low = 0
		high = list.size
		num = 15

		while (low <= high)
			mid = (low + high) / 2
			url = url_rule.sub('{x}', mid.to_s)
			page = get_page(url)
			list = get_list(page, list_ignore_links)

			if (list.length > 0)
				text = list.join("|")
				if (text =~ /<##>#{date}/)
					return page, mid, url_rule
				else
					start_date = list.first[/<##>([0-9]{6})[0-9]+<##>/, 1].to_i
					end_date = list.last[/<##>([0-9]{6})[0-9]+<##>/, 1].to_i
					# puts mid
					if (start_date > date && end_date > date)
						low = mid + 1
					else
						high = mid - 1
					end
					next
				end
			end
			high = mid - 1
		end
		
		return nil, mid, url_rule
	end
=end
	def get_news(url)
		page = get_page(url)
		page2 = get_next_page(page, 2)
		list_ignore_links = get_ignore_links(page, page2)
		#~ for item in list_ignore_links
			#~ puts item
		#~ end
		puts list =  get_list(page, list_ignore_links)
		#~ puts list_ignore_links
		puts list2 =  get_list(page2, list_ignore_links)
	end
end

robot = NetRobot.new
robot.get_news('http://www.mod.gov.cn/diplomacy/node_46942.htm')

=begin
#~ http://sousuo.gov.cn/column/30469/0.htm
#~ http://www.bygzjy.cn/f/trade/annogoods/list?index=MQ==
#~ http://www.ahzfcg.gov.cn/cmsNewsController/getZcfgNewsList.do?channelCode=zcfg
#~ http://www.xinhuanet.com/mil/yuejunqing.htm
#~ http://www.mod.gov.cn/action/node_46956.htm
#~ http://www.aqzfcg.gov.cn/CmsNewsController.do?method=newsList&channelCode=zfcg_1080&parentCode=sjcg&param=bulletin&rp=20&page=1
#~ http://www.aqzfcg.gov.cn/CmsNewsController.do?method=newsList&channelCode=zfcg_1080&parentCode=sjcg&param=bulletin&rp=20&page=2
=end

