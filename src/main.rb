#!/usr/bin/env ruby

# 取りこぼしある？
# たまに繋げられない問題
require 'net/https'
require 'io/console'
require 'nokogiri'
require 'open-uri'
require 'fileutils'

def login_nicovideo(mail)

	print("Pass: ")
	pass = STDIN.noecho(&:gets).chomp()
	puts
	
	host = 'secure.nicovideo.jp'
	path = '/secure/login?site=niconico'
	body = "mail=#{mail}&password=#{pass}"
	https = Net::HTTP.new(host, 443)
	https.use_ssl = true
	https.verify_mode = OpenSSL::SSL::VERIFY_NONE
#	# post_formは使えないっぽい
	response = https.start { |https|
	  https.post(path, body)
	}

	cookie = ''
	response['set-cookie'].split('; ').each do |st|
		if idx=st.index('user_session_')
			cookie = "user_session=#{st[idx..-1]}"
		break
		end
	end
	
	return cookie
end

def get_response(cookie, path)
	host = 'seiga.nicovideo.jp'
	# ここのページ取得がよく分かってない。
	return Net::HTTP.new(host).start { |http|
		request = Net::HTTP::Get.new(path)
		request['cookie'] = cookie
		http.request(request)
	}
end
def get_chapter_url(cookie, path = "/comic/2783/")
	response = get_response(cookie, path)

	doc = Nokogiri::HTML.parse(response.body)#, nil)#, charset)
	# eachの時だけ辞書っぽくアクセスしなきゃならんのが謎なので不採用
	# あと、いちいちループ毎にリストに追加する事になりそうで汚いのでそっちの意味でも却下
	#	doc.css('a').each do |anchor|
	#		p anchor[:href]
	#	end
	# Nokogiriでattributeがhrefの部分だけとりだして、正規表現にかけるほうが良かった。やり方わからんが
	chapter_url = doc.css('a').select { |anchor|
		# has_attributeがない？get_atrとatrの違い.value?
		anchor.get_attribute('href').match(/\/watch\/mg\d+\?track=ct_episode/)
		#anchor.attribute == "href"
	}.map { |anchor|
		anchor.attribute('href').value
	}
	return chapter_url.uniq
end

def get_chapter(cookie, path)
	response = get_response(cookie, path)
	# gsubも置換後の文字列を返すはずなのに、何も返さないのはなぜ？
	# 肯定的先読みで綺麗に表現できそう。
	return response.body.scan(/^.*data-original.*$/).map{|line| line.match(/\"http:\/\/lohas\.nicoseiga\.jp\/thumb\/.*\"/).to_s}.map{|line| line.gsub!(/^\"/, "").to_s}.map{|line| line.gsub!(/\"$/, "").to_s}.reject{|line| line == ""}
end

def save_url(url, file_name=File.basename(url), dir_name)
	# 別ディレクトリから実行した時のディレクトリの扱い
	# Titleから漫画名とか取得したい。
	dir_name =  "../comics/#{dir_name}"
	file_path = File.join(dir_name, file_name)
	puts dir_name

	FileUtils.mkdir_p(dir_name)

	open(file_path, 'wb') do |output|
		open(url) do |data|
			output.write(data.read)
		end
	end
end

# comic のタイトルにクッキーいらんくね
def get_title(cookie, path="/comic/2783/")
	response = get_response(cookie, path)

	doc = Nokogiri::HTML.parse(response.body)
	return doc.css('//meta[property="og:title"]/@content').to_s.gsub(/\//, "-")
end

cookie = login_nicovideo("dmcvpedf1@yahoo.co.jp")
title = get_title(cookie)
paths = get_chapter_url(cookie)
# path を可変に
for path, ind in paths.each_with_index
	chapter = get_title(cookie, path)
	pict_urls = get_chapter(cookie, path)
	pict_urls.each_with_index do |pict_url, i|
		puts pict_url
		file_name="#{i}.JPEG"
		# 拡張子判別機能 JPEG
		save_url(pict_url, file_name, File.join(title, chapter))
	end
end
