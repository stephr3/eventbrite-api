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

START_TO_END_TIMES = 
	{
		"10:25": "11:10",
		"11:35": "12:20",
		"10:50": "12:20",
		"13:10": "14:40",
		"14:50": "16:20",
		"16:30": "18:00"
	}	

####################################################################################

def create_workshops
	
	# open csv and store as array
	# note: columns in CSV should not be duplicate. EL1 / EL2 / EL3 is okay
	plaza_schedule = get_plaza_schedule
	plaza_schedule = [plaza_schedule[0]]  # remove later

	# create events
	plaza_schedule.each do |teacher_schedule|
		# store teacher and create array of events
		current_teacher = teacher_schedule["Name"]
		teacher_events = get_teacher_events(teacher_schedule)
		teacher_events = [teacher_events[0]]  # remove later
		puts "**************************************************************"
		puts "Creating events for #{current_teacher}"

		teacher_events.each do |event|
			# find appropriate master event
			master_event_id = MASTER_WORKSHOP_IDS["#{event[:type]}_#{event[:start_time]}".to_sym]

			# copy master event / store event id
			current_parent_event_id = copy_event(master_event_id, current_teacher, event)
			puts "Created event for #{event[:type].gsub("_", " ")} with #{current_teacher} #{event[:day]} at #{event[:start_time]}"
			puts "Event ID: #{current_parent_event_id}"

			# update details of new copy
			# schedule series using day, time, and parent event id (figure out start date from day)
			# get ticket class ids for parent event. Update sales_end_relative to end_time / offset 60
			# delete holiday events from series events
		end
	end
end

def get_plaza_schedule
	puts "**************************************************************"
	puts "Creating Workshops from #{CSV_FILE_NAME}"
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
	123
	# call url with HTTP::NET
	# return event id
end

def get_iso_datetime(day, time)
	date = START_DATES[day.to_sym]
	utc_time = JST_TO_UTC[time.to_sym]
	"#{date}T#{utc_time}:00Z"	
end

create_workshops

























