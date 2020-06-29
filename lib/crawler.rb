require 'HTTParty'
require 'nokogiri'
require 'fileutils'
require 'csv'

class Crawler
    def initialize
        @file = "#{File.expand_path File.dirname(__FILE__)}/watched.csv"
        @base_url = "https://filmow.com/usuario/paulo_alves"

        CSV.open(@file, "w") do |csv|
            csv << ["Title", "Rating"]
        end

        movies_content = page_content("#{@base_url}/filmes/ja-vi")
        shorts_content = page_content("#{@base_url}/curtas/ja-vi")
        tv_content = page_content("#{@base_url}/tv/ja-vi")

        movies_pages = number_pages(movies_content)
        shorts_pages = number_pages(shorts_content)
        tv_pages = number_pages(tv_content)

        crawl_pages(movies_pages, "filmes")
        crawl_pages(shorts_pages, "curtas")
        crawl_pages(tv_pages, "tv")
        # puts "TOTAL ITEMS: #{movies_pks.size + shorts_pks.size + tv_pks.size}"
    end

    def page_content(url)
        page = Nokogiri::HTML(HTTParty.get(url))
    end

    def number_pages(content)
        if content.css(".icon-double-angle-right").xpath("../@href").any?
            return content.css(".icon-double-angle-right").xpath("../@href").to_s.split("pagina\=").last.to_i
        elsif content.css("#next-page").any?
            return content.css(".pagination-centered").xpath(".//a[@href]")[-2].text.to_i
        else
            return 1
        end     
    end

    def crawl_pages(pages, type)
        puts "--------------------------------------------------------------------------------------------------"
        puts "Extracting #{type} from #{pages} pages"
        pks = []
        (1..pages).each do |page|
            puts "Going through page #{page}..."
            content = page_content("#{@base_url}/#{type}/ja-vi/?pagina=#{page}")
            
            # pks = pks + get_pks(content)
            add_to_csv(content)
        end

        # info_from_page(pks)
        # puts "TOTAL DE #{type.upcase}: #{pks.size}"
    end

    def add_to_csv(content)
        CSV.open(@file, "ab") do |csv|
            content.css("li.movie_list_item").each do |item|
                rating = item.css("span.star-rating-small")[0]["title"].to_s[/Nota:\ (.*?)\ estrela/m, 1].to_f
                title  = item.css("img.lazyload")[0]["alt"].to_s[/\((.*?)\)/m, 1]
                title = "PQP"  if unless.match(/^p{L}&&[a-zA-Z0-9_\-+ ]*$/)
                csv << [title, rating]
                puts "Adding |#{title}, rating #{rating}| to your file"
            end
        end


        # puts movie.to_s.match(/\(([^)]+)\)/)[1]
    end

    # def info_from_page(pks)
    #     pks.each do |pk|
    #         page = HTTParty.get("https://filmow.com/async/tooltip/movie/?movie_pk=#{pk.to_s}")
    #         rows = []
    #         rows << [page["movie"]["title_orig"], 5]
    #         puts "Adding '#{page["movie"]["title_orig"]}' to your file"
    #         CSV.open(@file, "ab") do |csv|
    #             rows.each do |row|
    #                 csv << row
    #             end
    #         end
    #         # page_html = Nokogiri::HTML(page["movie"]["html"])
    #         # info << page
    #     end
    # end

    result = Crawler.new

end