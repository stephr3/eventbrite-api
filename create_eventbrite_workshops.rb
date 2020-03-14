require 'net/http'
require 'json'
require 'date'
require 'csv'


####################################################################################
# update these dates for each term

START_DATES = {
					"Monday": "04-06-2020",
					"Tuesday": "04-07-2020",
					"Wednesday": "04-08-2020",
					"Thursday": "04-02-2020",
					"Friday": "04-03-2020"

			  }	

HOLIDAYS = ["05-04-2020", "05-05-2020", "05-06-2020", "06-05-2020", "07-16-2020"]

# update the csv file name if changed
CSV_FILE_NAME = "Plaza_Schedule_Spring_2020.csv"
####################################################################################


MASTER_WORKSHOP_IDS = 
	{
		"AA_10:25": "99794506054",
		"AA_11:35": "99794626414",
		"AA_10:50": "99514324022",
		"AA_1:10": "99794211172",
		"AA_2:50": "99794339556",
		"AA_4:30": "99794383688",
		"EL_10:25": "99795671540",
		"EL_11:35": "99795866122",
		"EL_10:50": "99795049680",
		"EL_1:10": "99514757318",
		"EL_2:50": "99795188094",
		"EL_4:30": "99795334532"
	}

MILITARY_TO_STANDARD = 
	{
		"10:25": "10:25",
		"10:50": "10:50",
		"11:35": "11:35",
		"13:10": "1:10",
		"14:50": "2:50",
		"16:30": "4:30"
	}

def create_workshops
	current_teacher = ""
	current_parent_event_id = ""
	current_day = ""
	current_time = ""
	current_type = ""
	plaza_schedule = []
	
	# open csv and store as array
	# note: columns in CSV should not be duplicate. EL1 / EL2 / EL3 is okay
	plaza_schedule = create_plaza_schedule

	# create events
	plaza_schedule.each do |teacher_schedule|
		# store teacher and create array of events
		current_teacher = teacher_schedule["Name"]
		teacher_events = get_teacher_events(teacher_schedule)
		puts "//////////////"
		puts current_teacher

		teacher_events.each do |event|
			#store event day, start time, and type
			puts event
			info_array = event.split(" ")
			current_type = info_array[0]
			current_day = info_array[1]
			current_start_time = get_start_time(info_array[2])

			# find appropriate master event
			current_parent_event_id = MASTER_WORKSHOP_IDS["#{current_type}_#{current_start_time}".to_sym]
			puts current_parent_event_id

			# copy master event / store event id
			# update title and details of new copy
			# schedule series using day, time, and parent event id (figure out start date from day)
			# get ticket class ids for parent event. Update sales_end_relative to end_time / offset 60
			# delete holiday events from series events
		end

	end
		


end

def create_plaza_schedule
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
		event = "#{event_type} #{v}"
		teacher_events.push(event)
	end
	teacher_events
end

def get_start_time(start_end_time)
	military_time = start_end_time.split("-").first.to_sym
	MILITARY_TO_STANDARD[military_time]
end

create_workshops

























