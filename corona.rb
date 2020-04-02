require 'net/http'
require 'date'
require 'csv'

PRIORITY = ["Brazil", "Italy", "Spain", "United States"]
REMOVE = ["World"]

timestamp = DateTime.now.strftime('%Y-%m-%d')

# FETCH DATA
client = Net::HTTP.new('covid.ourworldindata.org', 443)
client.use_ssl = true
csv_content = client.request_get('/data/ecdc/total_deaths.csv').body
File.open("#{timestamp}-input.csv", 'w') {|f| f << csv_content}
File.open("input.csv", 'w') {|f| f << csv_content}
csv = CSV.parse(csv_content)

class MovingAverage
    def initialize(size: )
        @maxsize = size
        @values = []
    end

    def push(value)
        @values << value
        while @values.size > @maxsize
            @values.shift
        end
    end

    def calculate
        return nil if @values.size < @maxsize
        (@values.reduce(:+) / @maxsize.to_f).round(2)
    end
end

class Country
    attr_reader :name

    def initialize(name)
        @name = name
        @deaths = []
    end

    def add_deaths(date_str, deaths)
        return if deaths.to_i <= 0
        @deaths.push(date: Date.parse(date_str), amount: deaths.to_i)
        @deaths.sort_by!{|d| d[:date]}
    end

    def total_deaths
        return 0 if @deaths.empty?
        @deaths.last[:amount]
    end

    def each_day(&block)
        deaths_moving_avg = MovingAverage.new(size: 6)
        day_deaths_moving_avg = MovingAverage.new(size: 6)
        @deaths.each_with_index do |data, inx|
            date = data[:date]
            deaths = data[:amount]
            previous_day_deaths = inx.zero? ? 0 : @deaths[inx-1][:amount]
            day_deaths = deaths - previous_day_deaths
            deaths_moving_avg.push(deaths)
            day_deaths_moving_avg.push(day_deaths)
            yield inx, date, deaths, deaths_moving_avg.calculate, day_deaths, day_deaths_moving_avg.calculate
        end
    end

    def days_size
        @deaths.size
    end
end

# BUILD ARRAY OF COUNTRIES WITH THE FETCHED DATA
countries = {}
country_names = csv[0]
csv.each.with_index do |row, row_i|
    next if row_i.zero?
    date_str = row[0]
    row.each_with_index do |deaths, col_i|
        next if col_i.zero?
        country_name = country_names[col_i]
        next if REMOVE.include?(country_name)
        countries[country_name] ||= Country.new(country_name)
        countries[country_name].add_deaths(date_str, deaths)
    end
end

all_countries = countries.values.find_all{|c| c.total_deaths > 0}.sort_by{|c| PRIORITY.reverse.index(c.name) ? PRIORITY.reverse.index(c.name)+10**10 : c.total_deaths}.reverse

# BUILD CSV DATA ARRAY
STATS_DAY_COLUMNS = 1   # day-number
COLUMNS_PER_COUNTRY = 5 # date | total-deaths ABS | total-deaths MAvg | day-deaths ABS | day-deaths MAvg
HEADER_ROWS = 3         # country | measure | statistic
stats = []
stats[0] = [nil] + all_countries.map{|c| [c.name]*COLUMNS_PER_COUNTRY}.flatten
stats[1] = [nil] + [nil, "Total Deaths", "Total Deaths", "Day Deaths", "Day Deaths"]*all_countries.size
stats[2] = [nil] + ["Date", "Absolute", "Moving Average", "Absolute", "Moving Average"]*all_countries.size

all_countries.each_with_index do |country, country_inx|
    country.each_day do |inx, date, total_deaths, total_deaths_ma, day_deaths, day_deaths_ma|
        stats[inx+HEADER_ROWS] ||= (["Day #{inx+1}"] + [nil]*COLUMNS_PER_COUNTRY*all_countries.size)
        row = stats[inx+HEADER_ROWS]
        country_inx_offset = STATS_DAY_COLUMNS + country_inx*COLUMNS_PER_COUNTRY
        row[country_inx_offset] = date
        row[country_inx_offset+1] = total_deaths
        row[country_inx_offset+2] = total_deaths_ma
        row[country_inx_offset+3] = day_deaths
        row[country_inx_offset+4] = day_deaths_ma
    end
end

# ADD DATES TO DAYS WITH NO DATA
max_days = all_countries.map(&:days_size).max
for i in 0...all_countries.size
    date_inx = STATS_DAY_COLUMNS + i*COLUMNS_PER_COUNTRY
    for j in 0...max_days
        next if j.zero?
        inx = j + HEADER_ROWS
        stats[inx][date_inx] = stats[inx-1][date_inx] + 1
    end
end

# WRITE CSV
CSV.open("#{timestamp}-output.csv", 'w') do |csv|
    stats.each{|row| csv << row}
end

CSV.open("output.csv", 'w') do |csv|
    stats.each{|row| csv << row}
end