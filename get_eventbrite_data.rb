
require 'net/http'
require 'json'
require 'date'

def get_eventbrite_data
	
	if !correct_input
		puts "Please input EL, AA, PEP, or PAW. Example: $ruby get_eventbrite_data.rb EL"
		return
	end

	# Get and filter events to be AA, EL, PEP, or PAW
	event_list = get_event_list

	# Grab event "id" with event "name.text", and "start.local" (as date, not date time) and put in an array
	formatted_events = get_formatted_events(event_list)
	puts "Events Retrieved: " + formatted_events.length.to_s
	puts formatted_events

	# attendees = get_attendees(formatted_events)

	# csv = create_csv(attendees)

	# open_csv(csv)

	# make into executable file...
end

def get_event_list
	event_list = []
	response_body = get_response_body(get_event_list_uri)
  	
  	raise StandardError.new("There are no events for this search") if !response_body
	event_list.push(response_body["events"]) 
	puts "Total Events: " + response_body["pagination"]["object_count"].to_s
	output_pages_complete(response_body["pagination"])
	
	while response_body["pagination"]["has_more_items"]
		continuation_uri = get_event_list_uri + "&continuation=" + response_body["pagination"]["continuation"]
		response_body = get_response_body(continuation_uri)
		raise StandardError.new("There was an error retrieving all events for this search") if !response_body
		puts response_body["pagination"]["page_number"].to_s + " of " +  response_body["pagination"]["page_count"].to_s + " pages retrieved"
		event_list.push(response_body["events"])
	end
	event_list 
end

def get_formatted_events(event_list) 
	ids_list = []
	event_list.each do |event_group|
		event_group.each do |event|
			ids_list.push({"name": event["name"]["text"], "id": event["id"], "date": Date.parse(event["start"]["local"]).to_s})
		end
	end
	ids_list
end

# def get_attendees(formatted_events)
# 	attendees_list = []
# 	# formatted_events.each do |formatted_event|
# 		response_body = get_response_body(get_attendees_uri(formatted_events[0][:id]))
# 		formatted_response = get_formatted_attendees(formatted_events[0], response_body)
# 		# attendees_list.push(formatted_response)
# 	# end
# 	# attendees_list
# end

# def get_formatted_attendees(event, attendees)
# 	puts "Event:"
# 	puts event
# 	puts "Attendees:"
# 	puts attendees
# end

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

def correct_input
	input && ["EL", "AA", "PEP", "PAW"].include?(input)
end

def input
	ARGV[0]
end

def organization_id
	ENV["EVENTBRITE_ORG_ID"]
end

def bearer_token
	ENV["EVENTBRITE_BEARER_TOKEN"]
end

def event_type
	case input
	when "EL"
	  "English Lounge"
	when "AA"
	  "Academic Advising"
	else
	  input
	end
end

def get_event_list_uri
	# "https://www.eventbriteapi.com/v3/organizations/#{organization_id}/events/?page_size=200&name_filter=#{event_type}"
	"https://www.eventbriteapi.com/v3/organizations/#{organization_id}/events/?page_size=200&name_filter=#{event_type} with Stephanie Roth"
end

# def get_attendees_uri(event_id)
# 	"https://www.eventbriteapi.com/v3/events/#{event_id}/attendees/"
# end

get_eventbrite_data
