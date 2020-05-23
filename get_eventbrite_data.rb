
require 'net/http'
require 'json'
require 'date'
require 'csv'

# Not used - use get_eventbrite_data_by_series instead

def get_eventbrite_data
	
	if !correct_event_type_input
		puts "Please input EL, AA, PEP, or PAW. Example: $ruby get_eventbrite_data.rb EL"
		return
	end

	if teacher_name_input && !correct_teacher_name_input
		puts "Please input the teacher's first and last name with an underscore between. Example: $ruby get_eventbrite_data.rb EL Jack_Johnson"
		return
	end

	# Get and filter events to be AA, EL, PEP, or PAW
	event_list = get_event_list

	# Grab event "id" with event "name.text", and "start.local" (as date, not date time) and put in an array
	formatted_events = get_formatted_events(event_list)
	puts "Events Retrieved: " + formatted_events.length.to_s

	attendees = get_attendees(formatted_events)

	open_csv(attendees.flatten)

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
	semester_start_date = Date.new(2020, 04, 29)
	today = Date.today
	event_list.each do |event_group|
		event_group.each do |event|
			event_date = Date.parse(event["start"]["local"])
			if event_date > semester_start_date && event_date < today
				ids_list.push({"name": event["name"]["text"], "id": event["id"], "date": event_date.to_s})
			end
		end
	end
	puts "Total of " + ids_list.length + " events completed before " + today.to_s
	ids_list
end

def get_attendees(formatted_events)
	attendees_list = []

	formatted_events.each_with_index do |formatted_event, i|
		response_body = get_response_body(get_attendees_uri(formatted_event[:id]))
		raise StandardError.new("There was an error retrieving attendees for this search") if !response_body
		formatted_response = get_formatted_attendees(formatted_event, response_body["attendees"])
		attendees_list.push(formatted_response)
		puts (i + 1).to_s + " of " + formatted_events.length.to_s + " events complete" if (i + 1) % 5 == 0
	end

	attendees_list
end

def get_formatted_attendees(event, attendees)
	attendees_list = []

	attendees.each do |attendee|
		next if !attendee["checked_in"]
		attendees_list.push(create_attendee(event, attendee))
	end

	attendees_list
end

def create_attendee(event, attendee)
	is_el ? english_lounge_pep_data(event, attendee) : academic_advising_paw_data(event, attendee)
end

def english_lounge_pep_data(event, attendee)
	{
		"Event Name": event[:name], 
		"First Name": attendee["profile"]["first_name"],
		"Last Name": attendee["profile"]["last_name"],
		"Email": attendee["profile"]["email"],
		"Ticket Type": attendee["ticket_class_name"],
		"Date Attending": event[:date],
		"What is your year/position at TIU?": attendee["answers"][0]["answer"],
		"What is your major/specialty at TIU?": attendee["answers"][1]["answer"],
		"Why are you coming to English Lounge?": attendee["answers"][2]["answer"],
		"Who teaches your CB class?": attendee["answers"][4]["answer"],
		"Who teaches your EP class?": attendee["answers"][5]["answer"],
		"Who teaches this class?": attendee["answers"][6]["answer"]
	}	
end

def academic_advising_paw_data(event, attendee)
	{
		"Event Name": event[:name], 
		"First Name": attendee["profile"]["first_name"],
		"Last Name": attendee["profile"]["last_name"],
		"Email": attendee["profile"]["email"],
		"Ticket Type": attendee["ticket_class_name"],
		"Date Attending": event[:date],
		"What is your year/position at TIU?": attendee["answers"][0]["answer"],
		"What is your major/specialty at TIU?": attendee["answers"][1]["answer"],
		"Why are you coming to Academic Advising?": attendee["answers"][2]["answer"],
		"Who teaches your AC1 class?": attendee["answers"][5]["answer"],
		"Who teaches your AC2 class?": attendee["answers"][6]["answer"],
		"Who teaches your EC/BW class?": attendee["answers"][7]["answer"],
		"Who teaches your CC class?": attendee["answers"][8]["answer"],
		"Who teaches your CB/BS class?": attendee["answers"][9]["answer"],
		"Who teaches this class?": attendee["answers"][10]["answer"],
		"What assignment, project, or topic are you bringing to Academic Advising?": attendee["answers"][3]["answer"]
	}	
end

def open_csv(attendees)
	file_name = "#{event_type_input}_#{Date.today.strftime("%m_%d_%Y")}.csv"
	CSV.open(file_name, "wb") do |csv|
  		csv << attendees.first.keys # adds the attributes name on the first line
	  	attendees.each do |hash|
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

def correct_event_type_input
	event_type_input && ["EL", "AA", "PEP", "PAW"].include?(event_type_input)
end

def correct_teacher_name_input
	teacher_name_input.include?("_")
end

def event_type_input
	ARGV[0]
end

def teacher_name_input
	ARGV[1]
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

def teacher_name
	teacher_name_input ? teacher_name_input.gsub("_", " ") : nil
end

def is_el
	event_type_input == "EL" || event_type_input == "PEP"
end

def get_event_list_uri
	if teacher_name
		"https://www.eventbriteapi.com/v3/organizations/#{organization_id}/events/?page_size=200&status=completed&time_filter=current_future&name_filter=#{event_type} with #{teacher_name}"
	else
		"https://www.eventbriteapi.com/v3/organizations/#{organization_id}/events/?page_size=200&status=completed&time_filter=current_future&name_filter=#{event_type}"
	end
end

def get_attendees_uri(event_id)
	"https://www.eventbriteapi.com/v3/events/#{event_id}/attendees/"
end

get_eventbrite_data
