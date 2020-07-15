require "colorize"
require "csv"
require "nokogiri"
require httparty"

class Crawler
    def initialize
        init_time = Time.now
        user_entry = get_user_entry
        @base_url = "https://filmow.com/usuario/#{user_entry[:username]}"

        user_entry[:options].each do |option|
            @file = "#{File.expand_path File.dirname(__FILE__)}/#{option[0]}"

            CSV.open(@file, "w") do |csv|
                csv << ["Title", "Rating"]
            end

            crawl_pages("filmes", option[1])
            crawl_pages("curtas", option[1])
            crawl_pages("tv", option[1])
            puts "TEMPO TOTAL: #{Time.now - init_time}"
        end
    end

    def get_user_entry
        response = {}
        puts "Please type the account username.\nFor example, for 'https://filmow.com/usuario/abc_123', just enter abc_123".light_yellow
        response[:username] = gets.chomp
        #stop execution in case of empty string
        abort "ERROR - No username.".red if response[:username].empty?

        summary_text = "Thank you.\nWait while information from username: #{response[:username]} are extracted to "

        puts "Type 1 for WATCHED\nOR\nType 2 for WATCHLIST\nOR\nType 3 for BOTH".light_yellow
        case gets.chomp
        when "1"
            response[:options] = [["watched.csv", "ja-vi"]]
            summary_text << "the file '#{response[:options][0][0]}'."
        when "2"
            response[:options] = [["watchlist.csv", "quero-ver"]]
            summary_text << "the file '#{response[:options][0][0]}'."
        when "3"
            response[:options] = [["watched.csv", "ja-vi"], ["watchlist.csv", "quero-ver"]]
            summary_text << "the files '#{response[:options][0][0]}' and '#{response[:options][1][0]}'."
        else
            #stop execution in case of invalid option
            abort "ERROR - Option not valid".red
        end

        puts summary_text.light_green

        response
    end

    def page_content(url)
        page = Nokogiri::HTML(HTTParty.get(url))
    end

    def get_number_of_pages(content)
        if content.css(".icon-double-angle-right").xpath("../@href").any?
            return content.css(".icon-double-angle-right").xpath("../@href").to_s.split("pagina\=").last.to_i
        elsif content.css("#next-page").any?
            return content.css(".pagination-centered").xpath(".//a[@href]")[-2].text.to_i
        else
            return 1
        end     
    end

    def crawl_pages(type, option)
        content = page_content("#{@base_url}/#{type}/#{option}")
        number_of_pages = get_number_of_pages(content)

        puts "--------------------------------------------------------------------------------------------------".light_cyan
        puts "Extracting #{type} from #{number_of_pages} pages".light_cyan
        pks = []
        (1..number_of_pages).each do |page|
            puts "Going through page #{page}...".light_magenta
            content = page_content("#{@base_url}/#{type}/#{option}/?pagina=#{page}")
            
            add_to_csv(content)
        end
    end

    def add_to_csv(content)
        CSV.open(@file, "ab") do |csv|
            content.css("li.movie_list_item").each do |item|
                rating = nil
                if item.css("span.star-rating-small").any?
                    rating = item.css("span.star-rating-small")[0]["title"].to_s[/Nota:\ (.*?)\ estrela/m, 1].to_f
                end
                title  = item.css("img.lazyload")[0]["alt"].to_s[/\((.*?)\)/m, 1]

                csv << [title, rating]
                puts "Adding |#{title}, rating #{rating}| to the file".light_blue
            end
        end
    end

    result = Crawler.new
end