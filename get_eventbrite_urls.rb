
require 'net/http'
require 'json'
require 'date'
require 'csv'

def get_eventbrite_urls

	# Get and filter events to be AA, EL, PEP, or PAW
	event_list = get_event_list

	# Grab relevant information
	formatted_events = get_formatted_events(event_list)
	puts "Events Retrieved: " + formatted_events.length.to_s

	open_csv(formatted_events.flatten)

end

def get_event_list
	event_list = []
	response_body = get_response_body(event_list_uri)
  	
  	raise StandardError.new("There are no events for this search") if !response_body
	event_list.push(response_body["events"]) 
	puts "Total Events: " + response_body["pagination"]["object_count"].to_s
	output_pages_complete(response_body["pagination"])
	
	while response_body["pagination"]["has_more_items"]
		continuation_uri = event_list_uri + "&continuation=" + response_body["pagination"]["continuation"]
		response_body = get_response_body(continuation_uri)
		raise StandardError.new("There was an error retrieving all events for this search") if !response_body
		puts response_body["pagination"]["page_number"].to_s + " of " +  response_body["pagination"]["page_count"].to_s + " pages retrieved"
		event_list.push(response_body["events"])
	end

	event_list 
end

def get_formatted_events(event_list) 
	urls_list = []

	event_list.each do |event_group|
		event_group.each do |event|
				urls_list.push({"name": event["name"]["text"], 
							"day": Date.parse(event["start"]["local"]).strftime('%A'),
							"time": DateTime.parse(event["start"]["local"]).strftime('%H:%M'), 
							"url": "https://www.eventbrite.com/e/#{event['series_id']}"
						   })
		end
	end

	unique_list = urls_list.uniq
	puts "Found #{unique_list.length} unique URLs"
	unique_list
end

def open_csv(events)
	file_name = "#{event_type}_URLS_#{Date.today.strftime("%m_%d_%Y")}.csv"
	CSV.open(file_name, "wb") do |csv|
  		csv << events.first.keys # adds the attributes name on the first line
	  	events.each do |hash|
	    	csv << hash.values
	  	end
	end
	puts "Created " + file_name
end

def get_response_body(uri_string)
	uri = URI.parse(uri_string)
	http = Net::HTTP.new(uri.host, uri.port)
	http.use_ssl = true
	request = Net::HTTP::Get.new(uri.request_uri)
  	request["Authorization"] = "Bearer #{bearer_token}"
  	response = http.request(request)
	response.is_a?(Net::HTTPSuccess) ? JSON.parse(response.body) : nil
end

def output_pages_complete(pagination_response)
		puts pagination_response["page_number"].to_s + " of " +  pagination_response["page_count"].to_s + " pages retrieved"
end

def event_type_input
	ARGV[0]
end

def organization_id
	ENV["EVENTBRITE_ORG_ID"]
end

def bearer_token
	ENV["EVENTBRITE_BEARER_TOKEN"]
end

def event_type
	case event_type_input
	when "EL"
	  "English Lounge"
	when "AA"
	  "Academic Advising"
	else
	  event_type_input
	end
end

def event_list_uri
	"https://www.eventbriteapi.com/v3/organizations/#{organization_id}/events/?page_size=200&status=live&name_filter=#{event_type}"
end

get_eventbrite_urls
