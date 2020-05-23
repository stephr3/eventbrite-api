
require 'net/http'
require 'json'
require 'date'
require 'csv'

# Update each term (can get IDs from URLS list)
EL_SERIES_IDS = [
					103063224880,
					103062990178,
					103066101484,
					103065355252,
					103063626080,
					103064566894,
					103065674206,
					103066482624,
					103063132604,
					103063706320,
					103067762452,
					103064129586,
					103064185754,
					103068063352,
					103063252964,
					103063796590,
					103062905926,
					103065146628,
					103063311138,
					103063922968,
					103065648128,
					103066508702,
					103064793572,
					103065088454,
					103065832680,
					103065622050,
					103063949046,
					103064623062,
					103064677224,
					103064735398,
					103066338192,
					103066454540,
					103063192784,
					103065116538,
					103062932004,
					103063672218,
					103066596966,
					103067309096,
					103066129568,
					103066424450,
					103067726344,
					103063102514,
					103063734404,
					103064592972,
					103065172706,
					103063764494,
					103062875836,
					103063016256,
					103063281048,
					103063888866,
					103062815656,
					103066294060
				]

AA_SERIES_IDS = [
					103066221844,
					103065060370,
					103067906884,
					103064649140,
					103066631068,
					103062845746,
					103067792542,
					103062962094,
					103063074430,
					103067579906,
					103066564870,
					103067876794,
					103063365300,
					103067820626,
					103068173682,
					103064007220,
					103068001166,
					103065710314,
					103066263970,
					103067696254,
					103068097454,
					103063393384,
					103068125538,
					103063166706,
					103063862788,
					103065297078,
					103064213838,
					103067638080,
					103067666164,
					103066191754,
					103064101502,
					103066396366,
					103067938980,
					103063824674,
					103067609996,
					103067848710,
					103063046346,
					103064705308,
					103066368282,
					103064035304,
					103067969070,
					103068201766,
					103063337216,
					103064157670,
					103065772500,
					103063975124,
					103064763482,
					103064063388,
					103065327168,
					103068031256,
					103065802590,
					103066159658,
					103066534780
				]

PEP_SERIES_IDS = [
					104744517672,
					104745085370,
					104745390282,
					104745442438,
					104745723278
				 ]

PAW_SERIES_IDS = []

def get_eventbrite_data_by_series
	
	if !correct_event_type_input
		puts "Please input EL, AA, PEP, or PAW. Example: $ruby get_eventbrite_data_by_series.rb EL"
		return
	end

	# Get past events by series ID
	event_list = get_event_list

	# Grab event "id" with event "name.text", and "start.local" (as date, not date time) and put in an array
	formatted_events = get_formatted_events(event_list)
	puts "Events Retrieved: " + formatted_events.length.to_s

	attendees = get_attendees(formatted_events)

	open_csv(attendees.flatten)

	# make into executable file...
end

def get_event_list
	series_ids_list = get_series_ids_list
	total_event_series = series_ids_list.length
	event_list = []
	puts "TOTAL EVENT SERIES: " + total_event_series.to_s
	puts "Step 1: Get completed events from each series..."

	series_ids_list.each_with_index do |series_id, i|
		event_list_uri = get_event_list_uri(series_id)
		response_body = get_response_body(event_list_uri)
  		raise StandardError.new("There are no events for this search") if !response_body
		event_list.push(response_body["events"])
		puts (i + 1).to_s + " of " + total_event_series.to_s + " series complete" if (i + 1) % 5 == 0
	end
	event_list 
end

def get_series_ids_list
	case event_type_input
	when "EL"
	  	EL_SERIES_IDS
	when "AA"
	  	AA_SERIES_IDS
	when "PEP"
		PEP_SERIES_IDS
	else
	  	PAW_SERIES_IDS
	end
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
	puts "Total of " + ids_list.length.to_s + " events completed before " + today.to_s
	ids_list
end

def get_attendees(formatted_events)
	attendees_list = []
	puts "Step 2: Get event attendee data..."
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
	case event_type_input
	when "EL"
	  	english_lounge_data(event, attendee)
	when "AA"
	  	academic_advising_data(event, attendee)
	when "PEP"
		pep_data(event, attendee)
	else
	  	paw_data(event, attendee)
	end	
end

def english_lounge_data(event, attendee)
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

def academic_advising_data(event, attendee)
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

def pep_data(event, attendee)
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
		"Who teaches your CB class?": attendee["answers"][5]["answer"],
		"Who teaches your EP class?": attendee["answers"][6]["answer"],
		"Who teaches this class?": attendee["answers"][7]["answer"]

	}
end

def paw_data(event, attendee)
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

def correct_event_type_input
	event_type_input && ["EL", "AA", "PEP", "PAW"].include?(event_type_input)
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

def get_event_list_uri(series_id)
	"https://www.eventbriteapi.com/v3/series/#{series_id}/events/?time_filter=past"
end

def get_attendees_uri(event_id)
	"https://www.eventbriteapi.com/v3/events/#{event_id}/attendees/"
end

get_eventbrite_data_by_series
