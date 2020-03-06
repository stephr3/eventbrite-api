
require 'net/http'
require 'json'
require 'date'

def get_eventbrite_data
	
	if !correct_input
		puts "Please input EL or AA. Example: $ruby get_eventbrite_data.rb EL"
		return
	end

	# # Get and filter events to be either AA or EL
	event_list = get_event_list

	# # Grab event "id" with event "name.text", and "start.local" (as date, not date time) and put in an array
	event_ids = get_event_ids(event_list)
	puts event_ids

	# attendees = get_attendees(event_ids)

	# csv = create_csv(attendees)

	# open_csv(csv)
end

def get_event_list
	uri = URI.parse(get_event_list_uri)
	http = Net::HTTP.new(uri.host, uri.port)
	http.use_ssl = true
	request = Net::HTTP::Get.new(uri.request_uri)
  	request["Authorization"] = "Bearer #{bearer_token}"

	response = http.request(request)
	JSON.parse(response.body)["events"] if response.is_a?(Net::HTTPSuccess)
	# Need to call again if more pages.. 
end

def get_event_ids(event_list) 
	ids_list = []
	event_list.each do |event|
		ids_list.push({"name": event["name"]["text"], "id": event["id"], "date": Date.parse(event["start"]["local"]).to_s})
	end
	ids_list
end


def correct_input
	input && input === "EL" || input === "AA"
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

def el_or_aa
	return "English Lounge" if is_EL? 
	"Academic Advising"
end

def get_event_list_uri
	"https://www.eventbriteapi.com/v3/organizations/#{organization_id}/events/?name_filter=#{el_or_aa} with Stephanie Roth"
end


def is_EL?
	input == "EL"
end

get_eventbrite_data
