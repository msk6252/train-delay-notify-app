# require 'httparty'
require 'net/http'
require 'uri'
require 'json'

CHECK_LIST = [
  {
    'name': '都営浅草線',
    'company': '都営地下鉄',
    'website': 'https://www.kotsu.metro.tokyo.jp/subway/schedule/asakusa.html'
  }
]

JSON_ADDR = 'https://tetsudo.rti-giken.jp/free/delay.json'
LINE_TOKEN = ENV['LINE_TOKEN']
LINE_URL = 'https://notify-api.line.me/api/notify'.freeze

def lambda_handler(event:, context:)

  details = []
  
  notify_delays = get_notify_delays()

  if notify_delays.empty?
    return
  end

  message, details = get_message(notify_delays)
  post_slack(message, details)
end

def get_notify_delays()
  current_delays = get_current_delays()
  notify_delays = []

  for delay_item in current_delays
    if ((!delay_item['name'].nil? && 
        !delay_item['name'].empty?) &&
        (!delay_item['company'].nil? && 
        !delay_item['company'].empty?))
      delay_item['name'].strip!
      delay_item['company'].strip!
    end
    for check_item in CHECK_LIST
      if ((!check_item[:name].nil? && 
          !check_item[:name].empty?) &&
          (!check_item[:company].nil? && 
          !check_item[:company].empty?))
          check_item[:name].strip!
          check_item[:company].strip!
        if delay_item['name'] == check_item[:name] && delay_item['company'] == check_item[:company]
          notify_delays.push(check_item)
        end
      end
    end
  end
  return notify_delays
end

def get_current_delays()
  begin
    res = URI.parse(JSON_ADDR)
    json = Net::HTTP.get(res)
    result = JSON.parse(json)
    return result
  rescue Exception => e
    puts e
  end
  return result
end

def get_message(delays)
  title = "\n 電車の遅延があります。"
  details = []

  puts delays
  for item in delays
    company =  item[:company]
    name = item[:name]
    website = item[:website]
    details.push("#{company} : #{name} #{website}")
  end

  return title, details
end

def post_slack(title, detail)
  uri = URI.parse(LINE_URL)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.start do
    request = Net::HTTP::Post.new(uri.path)
    request['Authorization'] = "Bearer #{LINE_TOKEN}"
    request.set_form_data(message: "#{title} \n #{detail}")
    http.request(request)
  end
end
