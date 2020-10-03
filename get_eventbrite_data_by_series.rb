
require 'net/http'
require 'json'
require 'date'
require 'csv'

# Update each term (can get IDs from URLS list)
EL_SERIES_IDS = [
					119983284233,
					119981322365,
					119983021447,
					119982419647,
					119982738601,
					119717136177,
					119717194351,
					119717288633,
					118748852013,
					119714251549,
					119715802187,
					119716438089,
					119716588539,
					119717092045,
					119715906499,
					119716002787,
					119716117129,
					119716209405,
					119716323747,
					119716383927
				]

AA_SERIES_IDS = [
					119718935559,
					119718991727,
					119719071967,
					119555147665,
					119717033871,
					119717240489,
					119718781097,
					119718837265,
					119718885409,
					119717645701,
					119717756031,
					119718245495,
					119718422023,
					119718530347,
					119718662743
				]

PEP_SERIES_IDS = [
					119961475001,
					119569299995,
					119961292455,
					119899997119,
					119961212215,
					119718522323,
					119557290073,
					119718345795,
					119717417017,
					119718227441
				 ]

PAW_SERIES_IDS = [
					121666055447,
					121482201535,
					121663443635,
					121660892003,
					1216612811677
				 ]

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
	when "PAW"
	  	PAW_SERIES_IDS
	end
end

def get_formatted_events(event_list) 
	ids_list = []
	semester_start_date = Date.new(2020, 9, 14) # update each semester
	today = Date.today
	event_list.each do |event_group|
		event_group.each do |event|
			event_date = Date.parse(event["start"]["local"])
			if event_date >= semester_start_date && event_date <= today
				ids_list.push({"name": event["name"]["text"], "id": event["id"], "date": event_date.to_s})
			end
		end
	end
	puts "Total of " + ids_list.length.to_s + " events completed up to and including " + today.to_s
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
	when "PAW"
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
		"Who teaches your BS/CB class?": attendee["answers"][5]["answer"],
		"Who teaches your EP class?": attendee["answers"][6]["answer"],
		"Who teaches this class?": attendee["answers"][7]["answer"]

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
		"Who teaches your EC/BW class?": "",
		"Who teaches your CC class?": "",
		"Who teaches your CB/BS class?": "",
		"Who teaches this class?": attendee["answers"][7]["answer"],
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
