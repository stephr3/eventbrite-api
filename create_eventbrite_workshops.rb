require 'net/http'
require 'json'
require 'date'
require 'csv'



# UPDATE THESE EACH TERM
####################################################################################
# yyyy-mm-dd format

START_DATES = {
					Monday: "2020-04-06",
					Tuesday: "2020-04-07",
					Wednesday: "2020-04-08",
					Thursday: "2020-04-02",
					Friday: "2020-04-03"

			  }	

HOLIDAYS = ["2020-05-04", "2020-05-05", "2020-05-06", "2020-06-05", "2020-07-16"]

CSV_FILE_NAME = "Plaza_Schedule_Spring_2020.csv"


MASTER_WORKSHOP_IDS = 
	{
		"Academic_Advising_10:25": "99794506054",
		"Academic_Advising_11:35": "99794626414",
		"Academic_Advising_10:50": "99514324022",
		"Academic_Advising_13:10": "99794211172",
		"Academic_Advising_14:50": "99794339556",
		"Academic_Advising_16:30": "99794383688",
		"English_Lounge_10:25": "99795671540",
		"English_Lounge_11:35": "99795866122",
		"English_Lounge_10:50": "99795049680",
		"English_Lounge_13:10": "99514757318",
		"English_Lounge_14:50": "99795188094",
		"English_Lounge_16:30": "99795334532"
	}

# How many times each day occurs in the semester, *including* holidays
FREQ_COUNTS = 
	{
		Monday: "15",
		Tuesday: "15",
		Wednesday: "15",
		Thursday: "16",
		Friday: "16"
	}

####################################################################################

JST_TO_UTC = 
	{
		"10:25": "01:25",
		"11:35": "02:35",
		"10:50": "01:50",
		"13:10": "04:10",
		"14:50": "05:50",
		"16:30": "07:30",
		"11:10": "02:10",
		"12:20": "03:20",
		"14:40": "05:40",
		"16:20": "07:20",
		"18:00": "09:00"		
	}	

####################################################################################

def create_workshops
	
	# open csv and store as array
	# note: columns in CSV should not be duplicate. EL1 / EL2 / EL3 is okay
	plaza_schedule = get_plaza_schedule
	# plaza_schedule = [plaza_schedule[1]]  # to test one event

	# create events
	plaza_schedule.each do |teacher_schedule|
		# store teacher and create array of events
		current_teacher = teacher_schedule["Name"]
		teacher_events = get_teacher_events(teacher_schedule)
		# teacher_events = [teacher_events[2]]  # to test one event
		puts "**************************************************************"
		puts "Creating events for #{current_teacher}..."
		puts "**************************************************************"

		teacher_events.each do |event|
			# find appropriate master event
			master_event_id = MASTER_WORKSHOP_IDS["#{event[:type]}_#{event[:start_time]}".to_sym]

			# copy master event / store event id
			copied_event = copy_event(master_event_id, current_teacher, event)
			parent_event_id = copied_event["id"]
			puts "Created event: #{event[:type].gsub("_", " ")} with #{current_teacher} #{event[:day]} at #{event[:start_time]}"
			puts "Event ID: #{parent_event_id}"

			# update details of new copy
			update_event_details(copied_event, current_teacher)

			# schedule series using day, time, and parent event id (figure out start date from day)
			schedule_series(parent_event_id, event[:start_time], event[:start_date], event[:day])

			# delete events from series events
			created_events = get_events_by_series(parent_event_id)
			events_to_delete = []

			created_events.each do |e|
				events_to_delete.push(e) if HOLIDAYS.include?(e[:date])
			end

			if events_to_delete.length
				events_to_delete.each do |e|
					delete_event(e[:id], e[:date])
				end
			end
			
			# publish series event
			publish_event(parent_event_id)
			puts "***Published event: #{event[:type].gsub("_", " ")} with #{current_teacher} #{event[:day]} at #{event[:start_time]}***"
		end
	end
end

def get_plaza_schedule
	puts "**************************************************************"
	puts "Creating Events from #{CSV_FILE_NAME}"
	schedule_array = CSV.open(CSV_FILE_NAME, headers: :first_row).map(&:to_h)
	schedule_array.each do |teacher_schedule| 
		teacher_schedule.delete_if { |k, v| v.nil? }
	end
	schedule_array
end

def get_teacher_events(teacher_schedule)
	teacher_events = []
	teacher_schedule = teacher_schedule.tap { |hs| hs.shift }
	teacher_schedule.each do |k,v|
		event_type = k.to_s.tr("0-9", "")
		event = formatted_event_hash(event_type, v)
		teacher_events.push(event)
	end
	teacher_events
end

def formatted_event_hash(event_type, value)
	val_array = value.split(" ")
	times_array = val_array[1].split("-")
	day = val_array[0]

	formatted_event_type = event_type == "EL" ? "English_Lounge" : "Academic_Advising"
	start_time = times_array[0]
	end_time = times_array[1] 
	start_date = get_iso_datetime(day, start_time)
	end_date = get_iso_datetime(day, end_time)

	{type: formatted_event_type, day: day, start_time: start_time, start_date: start_date, end_date: end_date}
end

def copy_event(master_event_id, current_teacher, event)
	event_type = event[:type].gsub("_", "%20")
	teacher_name = current_teacher.gsub(" ", "%20")
	event_name = "#{event_type}%20with%20#{teacher_name}"
	url = "https://www.eventbriteapi.com/v3/events/#{master_event_id}/copy/?name=#{event_name}&start_date=#{event[:start_date]}&end_date=#{event[:end_date]}&timezone=Asia/Tokyo"
	response_body = get_response_body(url, "post")
	raise StandardError.new("There was an error copying the master event") if !response_body
	response_body
end

def delete_event(event_id, event_date=nil)
	url = "https://www.eventbriteapi.com/v3/events/#{event_id}/"
	response_body = get_response_body(url, "delete")
	raise StandardError.new("There was an error deleting an event") if !response_body
	puts "Deleted holiday event on #{event_date} with ID #{event_id}"
end

def update_event_details(event, teacher_name)
	url = "https://www.eventbriteapi.com/v3/events/#{event["id"]}/"
	event["description"]["text"] = event["description"]["text"].gsub("FIRST_NAME", teacher_name)
	event["description"]["html"] = event["description"]["html"].gsub("FIRST_NAME", teacher_name)
	body = get_event_update_body(event).to_json
	response_body = get_response_body(url, "post", body)
	raise StandardError.new("There was an error updating the event details") if !response_body
end

def schedule_series(id, start_time, start_date, day)
	url = "https://www.eventbriteapi.com/v3/events/#{id}/schedules/"
	occurrence_duration = get_occurrence_duration(start_time)
	recurrence_rule = get_recurrence_rule(start_date, day)
	body = get_schedule_series_body(occurrence_duration, recurrence_rule).to_json
	response_body = get_response_body(url, "post", body)
	raise StandardError.new("There was an error scheduling the event series") if !response_body
end

def publish_event(id)
	url = "https://www.eventbriteapi.com/v3/events/#{id}/publish/"
	response_body = get_response_body(url, "post")
	raise StandardError.new("There was an error publishing an event") if !response_body
end

def get_events_by_series(id)
	url = "https://www.eventbriteapi.com/v3/series/#{id}/events/"
	response_body = get_response_body(url, "get")
	raise StandardError.new("There was an error retrieving the series events") if !response_body
	formatted_series_events(response_body["events"])
end

def formatted_series_events(events)
	formatted_events = []
	events.each do |event|
		formatted_events.push(id: event["id"], date: event["start"]["local"].split("T")[0])
	end
	formatted_events
end

def get_occurrence_duration(time)
	["10:25", "11:35"].include?(time) ? 2700 : 5400
end

def get_recurrence_rule(date, day)
	count = FREQ_COUNTS[day.to_sym]
	formatted_date = date.gsub("-","").gsub(":","")
	"DTSTART:#{formatted_date}\nRRULE:FREQ=WEEKLY;COUNT=#{count}"
end

def get_schedule_series_body(occurrence_duration, recurrence_rule)
	{
		"schedule": {
			"occurrence_duration": occurrence_duration,
			"recurrence_rule": recurrence_rule
		}
	}
end

def get_response_body(uri_string, type, body=nil)
	uri = URI.parse(uri_string)
	http = Net::HTTP.new(uri.host, uri.port)
	http.use_ssl = true
	request = get_request(type, uri)
  	request["Authorization"] = "Bearer #{bearer_token}"
  	if body
  		request["Content-Type"] = "application/json"
  		request.body = body 
  	end
  	response = http.request(request)
	response.is_a?(Net::HTTPSuccess) ? JSON.parse(response.body) : nil
end

def get_request(type, uri)
	case type
	when "delete"
		Net::HTTP::Delete.new(uri.request_uri)
	when "post"
		Net::HTTP::Post.new(uri.request_uri)
	else
		Net::HTTP::Get.new(uri.request_uri)
	end	
end

def get_event_update_body(event)
	 {
	  "event": {
	    "name": {
	      "html": event["name"]["html"]
	    },
	    "description": {
	      "html": event["description"]["html"]
	    },
	    "start": {
	      "timezone": event["start"]["timezone"],
	      "utc": event["start"]["utc"]
	    },
	    "end": {
	      "timezone": event["end"]["timezone"],
	      "utc": event["end"]["utc"]
	    },
	    "currency": event["currency"],
	    "online_event": event["online_event"],
	    "organizer_id": event["organizer_id"],
	    "listed": event["listed"],
	    "shareable": event["shareable"],
	    "invite_only": event["invite_only"],
	    "show_remaining": event["show_remaining"],
	    "password": event["password"],
	    "capacity": event["capacity"],
	    "is_reserved_seating": event["is_reserved_seating"],
	    "is_series": event["is_series"],
	    "show_pick_a_seat": event["show_pick_a_seat"],
	    "show_seatmap_thumbnail": event["show_seatmap_thumbnail"],
	    "show_colors_in_seatmap_thumbnail": event["show_colors_in_seatmap_thumbnail"]
	  }
	}
end

def get_iso_datetime(day, time)
	date = START_DATES[day.to_sym]
	utc_time = JST_TO_UTC[time.to_sym]
	"#{date}T#{utc_time}:00Z"	
end

def bearer_token
	ENV["EVENTBRITE_BEARER_TOKEN"]
end

create_workshops
# delete_event(ARGV[0])

























