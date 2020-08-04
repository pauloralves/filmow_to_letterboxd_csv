require 'colorize'
require 'csv'
require 'nokogiri'
require 'httparty'

class Crawler
    def initialize
        init_time = Time.now
        user_entry = get_user_entry
        @base_url = "https://filmow.com/usuario/#{user_entry[:username]}"

        @create_diary_entry = user_entry[:diary]
        user_entry[:options].each do |option|
            @file = "#{File.expand_path File.dirname(__FILE__)}/#{user_entry[:username]}_#{option[0]}"

            CSV.open(@file, 'w') do |csv|
                csv << ['Title', 'Director', 'Year', 'Rating', 'WatchedDate']
            end

            crawl_pages('filmes', option[1])
            crawl_pages('curtas', option[1])
            crawl_pages('tv', option[1])
        end
        puts "TOTAL EXECUTION TIME: #{Time.now - init_time} seconds".light_black
        puts "That's it!\nAll information was saved on your .csv file(s).".light_green
    end

    def get_user_entry
        response = {}
        puts "Please type the account username.\nFor example, for 'https://filmow.com/usuario/abc_123', just enter abc_123".light_magenta
        response[:username] = gets.chomp.split('filmow.com/usuario').last.gsub('/', '')
        puts response[:username]
        #stop execution in case of empty string
        abort 'ERROR - Invalid username.'.red if response[:username].empty?

        puts 'TYPE 1 for WATCHED OR TYPE 2 for WATCHLIST OR TYPE 3 for BOTH'.light_magenta
        case gets.chomp
        when '1'
            response[:options] = [['watched.csv', 'ja-vi']]
        when '2'
            response[:options] = [['watchlist.csv', 'quero-ver']]
        when '3'
            response[:options] = [['watched.csv', 'ja-vi'], ['watchlist.csv', 'quero-ver']]
        else
            #stop execution in case of invalid option
            abort 'ERROR - Option not valid'.red
        end

        puts "Would you like to create Diary entries with date of today for each movie? (It helps keeping track of future rewatcheds)\ny/n".light_magenta
        case gets.chomp
        when 'y'
            response[:diary] = true
        when 'n'
            response[:diary] = false
        else
            #stop execution in case of invalid option
            abort 'ERROR - Option not valid'.red
        end

        puts "Thank you.\nWait while information from #{response[:username]} is extracted.".light_green

        response
    end

    def page_content(url)
        Nokogiri::HTML(HTTParty.get(url))
    end

    def get_number_of_pages(content)
        if content.css('.icon-double-angle-right').xpath('../@href').any?
            return content.css('.icon-double-angle-right').xpath('../@href').to_s.split("pagina\=").last.to_i
        elsif content.css('#next-page').any?
            return content.css('.pagination-centered').xpath('.//a[@href]')[-2].text.to_i
        else
            return 1
        end     
    end

    def crawl_pages(type, option)
        content = page_content("#{@base_url}/#{type}/#{option}")
        number_of_pages = get_number_of_pages(content)

        puts "Extracting #{type} from #{number_of_pages} pages".cyan

        (1..number_of_pages).each do |page|
            puts "Going through page #{page}...".light_blue
            content = page_content("#{@base_url}/#{type}/#{option}/?pagina=#{page}")
            
            add_to_csv(content)
        end
    end

    def add_to_csv(content)
        CSV.open(@file, 'ab') do |csv|
            threads = []

            content.css('li.movie_list_item').each do |item|
                threads << Thread.new do
                    rating = nil
                    year   = nil

                    if item.css('span.star-rating-small').any?
                        rating = item.css('span.star-rating-small')[0]['title'].to_s[/Nota:\ (.*?)\ estrela/m, 1].to_f
                    end

                    title  = item.css('img.lazyload')[0]['alt'].to_s[/\((.*?)\)/m, 1]

                    pk = item['data-movie-pk']
                    pk_page = get_pk_link(pk)

                    info_divs = pk_page[:html].css("div.shortcut-movie-details").css("/div")

                    year = info_divs[1].text[/: (.*?)\n/m, 1][-4..-1]

                    director = info_divs[2].text[/: (.*?)\n/m, 1]

                    title  = pk_page[:movie]['title_orig']

                    diary_date = @create_diary_entry ? Time.now.strftime('%Y-%m-%d') : nil

                    csv << [title, director, year, rating, diary_date]

                    puts "|ADDING #{title} |DIRECTOR #{director} |YEAR #{year.nil? ? '-' : year} |RATING #{rating.nil? ? '-' : rating} |".light_yellow
                end
            end
            threads.map(&:join)
        end
    end

    def get_pk_link(pk)
        page = HTTParty.get("https://filmow.com/async/tooltip/movie/?movie_pk=#{pk}")
        { html: Nokogiri::HTML(page['html']), movie: page['movie'] }
    end

    Crawler.new
end