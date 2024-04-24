require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'
require 'date'
require 'time'
require_relative './model.rb'
require 'sinatra/flash'

# Enables session support in Sinatra for managing user sessions
enable :sessions

# Sets the environment for Sinatra to development mode for detailed error logs and live reloading
set :environment, :development

# Includes the methods defined in the Model module for use in route handlers
include Model

# Constants to manage login attempts and cooldown periods to prevent brute force attacks
MAX_ATTEMPTS = 3
INITIAL_COOLDOWN = 2
MAX_COOLDOWN = 300

# Route guard to restrict access to authenticated users and redirect unauthorized access to login
before do 
    if !['/', '/login', '/register', '/users/new'].include?(request.path_info) && session[:id].nil?
        redirect('/login')
    end

    if request.path_info == '/admin' && session[:user] != 'admin'
        redirect('/overview')
    end
end

# Implementing cooldown logic to limit login attempts after reaching MAX_ATTEMPTS
before '/login' do
    session[:attempts] ||= 0
    if session[:attempts] >= MAX_ATTEMPTS
        cooldown = [INITIAL_COOLDOWN * (2 ** (session[:attempts] - MAX_ATTEMPTS)), MAX_COOLDOWN].min
        if Time.now - (session[:last_attempt_time] || Time.now) < cooldown
            halt 429, "Too many attempts. Please wait #{cooldown - (Time.now - session[:last_attempt_time]).to_i} seconds."
        end
    end
end

# Helper functions to support various features in the application
helpers do
    # Returns the name of the weekday for a given date
    #
    # @param [Integer] year, The year of the date
    # @param [Integer] month, The month of the date
    # @param [Integer] day, The day of the date
    #
    # @return [String] The weekday name
    def get_weekday_from_date(year, month, day)
        date = Date.new(year.to_i, month.to_i, day.to_i)
        return date.strftime('%A')
    end

    # Returns the name of the month for a given month number
    #
    # @param [Integer] month, The month numberc
    #
    # @return [String] The name of the month
    def get_month_name(month)
        return Date::MONTHNAMES[month.to_i]
    end

    # Generates today's date details including day number, month number, month name, and year
    #
    # @return [Array] Details of today's date
    def get_todays_date()
        d = DateTime.now
        day_today = d.strftime("%d").to_i
        month_number_today = d.strftime("%m").to_i
        month_name_today = Date::MONTHNAMES[d.strftime("%m").to_i]
        year_today = d.strftime("%Y").to_i
        
        date = [].append(day_today, month_number_today, month_name_today, year_today)
        puts date
        return date
    end

    # Generates calendar information for a specific month and year
    #
    # @param [Integer] year, The year
    # @param [Integer] month, The month number
    #
    # @return [Array] Includes year, month name, total days in the month, and weekday of the first day
    def get_calendar(year, month)
        days = Date.new(year, month, -1).day
        first_day = Date.new(year, month, 1)
        puts first_day
        weekday = first_day.cwday
        month_information = [year, Date::MONTHNAMES[month], days, weekday]
        puts "--------"
        puts month_information
        return month_information
    end

    # Simple counter to increment a number by one
    #
    # @param [Integer] start_number, The number to be incremented
    #
    # @return [Integer] The incremented number
    def counter(start_number)
        return start_number += 1
    end
end


# Display Landing Page
#
get('/') do 
    slim :start, layout: false
end

# Displays a login form
get('/login') do 
    slim :login, layout: false
end

# Attempts to authenticate a user and sets session details upon successful login. Redirects to the overview page if successful, or prompts to try again if unsuccessful.
#
# @param [String] email The email entered by the user.
# @param [String] password The password entered by the user.
#
# @see Model#find_user_by_email
# @see Model#authenticate_user
post('/login') do
    email = params[:email]
    password = params[:password]
    result = find_user_by_email(email)

    if result.nil?
        p "User not found"
        redirect('/login')
    else
        if authenticate_user(password, result['pwdigest'])
            session[:id] = result['id']
            session[:user] = result['name']
            session[:user_email] = email
            redirect('/overview')
        else
            session[:last_attempt_time] = Time.now
            session[:attempts] += 1
            p "Wrong password"
        end
    end
end

# Displays a register form
#
get('/register') do
    slim :register, layout: false
end

# Registers a new user using provided details and redirects to login upon successful registration.
# Assumes validation of form data is handled on the client side.
#
# @param [String] firstname, The first name of the user.
# @param [String] lastname, The last name of the user.
# @param [String] email, The email address of the user.
# @param [String] password, The desired password.
# @param [String] password_confirm, The password confirmation, should match the password.
#
# @see Model#register_user
post('/users/new') do 
    firstname = params[:firstname]
    lastname = params[:lastname]
    email = params[:email]
    password = params[:password]
    password_confirm = params[:password_confirm]
    name = firstname.strip.capitalize + " " + lastname.strip.capitalize
    
    register_user(name, email, password, password_confirm)

    redirect('/login')
end

# Logs out user and clears the session
# 
get('/logout') do
    session.clear
    redirect('/')
end

# Displays admin page
#
get('/admin') do
    users = get_all_users()

    slim(:"/admin", locals: { users: users })
end

# Attempts to authenticate admin and deletes a user if successful. 
#
# @param [Integer] user_id, The ID of the user
#
# @see Model#authenticate_admin
# @see Model#delete_user
post('/:user/delete') do
    if authenticate_admin(session[:user])
        user_id = params[:user].to_i
        delete_user(user_id)
    end
    redirect('/admin')
end

# Displays an overview of today's and this week's workouts for the logged-in user
#
# @param [Integer] session[:id] The ID of the logged-in user
#
# @see Model#get_todays_workouts
# @see Model#get_weeks_workouts
get('/overview') do
    todays_workouts = get_todays_workouts(session[:id])
    weeks_workouts = get_weeks_workouts(session[:id])

    slim(:overview, locals: { todays_workouts: todays_workouts, weeks_workouts: weeks_workouts })
end

# Displays a list of all workouts for the logged-in user
#
# @param [Integer] session[:id] The ID of the logged-in user
#
# @see Model#get_workouts
get('/workouts') do 
    workouts = get_workouts(session[:id])

    slim(:"/workouts/index", locals: { workouts: workouts })
end

# Displays a form to create a new workout
#
get('/workouts/new') do 
    slim(:"/workouts/new")
end

# Creates a new workout based on provided details and redirects to the workouts list page
#
# @param [Integer] session[:id] The ID of the logged-in user
#
# @see Model#create_easy_run
# @see Model#create_tempo_run
# @see Model#create_interval_run
# @see Model#create_weight_workout
post('/workouts/new') do 
    title = params[:title]
    run_type = params[:run]
    weight_type = params[:weight]

    if run_type
        easy_run = params[:easy_run]
        tempo_run = params[:tempo_run]
        interval_run = params[:interval_run]

        if easy_run
            distance = params[:easy_distance]
            duration = params[:easy_time]

            create_easy_run(session[:id], title, distance, duration)
        elsif tempo_run
            distances = params[:tempo_distance]
            heart_rate_zones = params[:tempo_heart]

            create_tempo_run(session[:id], title, distances, heart_rate_zones)
        elsif interval_run
            durations = params[:interval_time]
            heart_rate_zones = params[:interval_heart]

            create_interval_run(session[:id], title, durations, heart_rate_zones)
        end
    elsif weight_type
        exercises = params[:exercise]
        sets = params[:sets]
        reps = params[:reps]
        time = params[:time]

        exercise_tot = []
        i = 0
        while i < exercises.length()
            exercise_group = []
            exercise_group.append(exercises[i])
            exercise_group.append(sets[i])
            exercise_group.append(reps[i])
            exercise_tot.append(exercise_group)
            i += 1
        end

        create_weight_workout(session[:id], title, exercise_tot, time)
    end
    
    redirect('/workouts')
end

# Displays a single workout
#
# @param [Integer] :id The ID of the workout
#
# @see Model#get_workout
# @see Model#get_exercises
# @see Model#get_run_details
get('/workouts/:id') do
    workout_id = params[:id].to_i
    workout = get_workout(workout_id)
    workout_type = workout["workout_type"]
    exercises = get_exercises(workout_id)
    run_details = get_run_details(workout_id)
    p "------------------"
    p run_details

    slim(:"/workouts/show", locals: { workout: workout, workout_type: workout_type, exercises: exercises, run_details: run_details })
end

# Deletes a workout and redirects to the workouts list
#
# @param [Integer] :id The ID of the workout
# @param [Integer] session[:id] The ID of the logged-in user
#
# @see Model#authenticate_workout
# @see Model#delete_workout
post('/workouts/:id/delete') do
    workout_id = params[:id].to_i
    if authenticate_workout(workout_id, session[:id])
        delete_workout(workout_id)
    end
    
    redirect('/workouts')
end

# Displays a form to edit an existing workout
#
# @param [Integer] :id The ID of the workout
#
# @see Model#get_workout
# @see Model#get_exercises
# @see Model#get_run_details
get('/workouts/:id/edit') do
    workout_id = params[:id].to_i
    workout = get_workout(workout_id)
    workout_type = workout["workout_type"]
    exercises = get_exercises(workout_id)
    run_details = get_run_details(workout_id)
    p "------------------"
    p run_details

    slim(:"/workouts/edit", locals: { workout: workout, workout_type: workout_type, exercises: exercises, run_details: run_details })
end

# Updates an existing workout and redirects to the workout details page
#
# @param [Integer] :id The ID of the workout to update
# @param [Integer] session[:id] The ID of the logged-in user
#
# @see Model#authenticate_workout
# @see Model#update_easy_run
# @see Model#update_tempo_run
# @see Model#update_interval_run
# @see Model#update_weight_workout
post('/workouts/:id/update') do
    workout_id = params[:id].to_i
    workout_type = get_workout_type(workout_id)

    if authenticate_workout(workout_id, session[:id])
        title = params[:title]
        p workout_type
        if workout_type == "easy_run"
            p "-----------"
            distance = params[:easy_distance]
            duration = params[:easy_time]
            p distance
            p duration

            update_easy_run(workout_id, title, distance, duration)
        elsif workout_type == "tempo_run"
            distances = params[:tempo_distance]
            heart_rate_zones = params[:tempo_heart]
            p "-----------"
            p distances
            p heart_rate_zones

            update_tempo_run(workout_id, title, distances, heart_rate_zones)
        elsif workout_type == "interval_run"
            durations = params[:interval_time]
            heart_rate_zones = params[:interval_heart]
            p "-----------"
            p durations
            p heart_rate_zones

            update_interval_run(workout_id, title, durations, heart_rate_zones)
        elsif workout_type == "weight"
            exercises = params[:exercise]
            sets = params[:sets]
            reps = params[:reps]

            exercise_tot = []
            i = 0
            while i < exercises.length()
                exercise_group = []
                exercise_group.append(exercises[i])
                exercise_group.append(sets[i])
                exercise_group.append(reps[i])
                exercise_tot.append(exercise_group)
                i += 1
            end

            update_weight_workout(workout_id, title, exercise_tot)
        end
    end
 
    redirect('/workouts')
end

# Displays the workouts on a specific date
#
# @param [Integer] session[:id] The ID of the user
# @param [String] date The specific date to show workouts for
#
# @see Model#date_get_workouts
get('/date/:year/:month/:day') do
    year = params[:year]
    month = params[:month]
    day = params[:day]
    date = year + "-" + month + "-" + day

    workouts = date_get_workouts(session[:id], date)
    slim(:"date/show", locals: { year: year, month: month, day: day, workouts: workouts })
end

# Displays a list of workouts to add to a specific date
#
# @param [Integer] session[:id] The ID of the user
#
# @see Model#get_workouts
get('/date/new/:year/:month/:day') do
    year = params[:year]
    month = params[:month]
    day = params[:day]
    date = "#{year}-#{month}-#{day}"

    workouts = get_workouts(session[:id])
    slim(:"date/new", locals: { year: year, month: month, day: day, workouts: workouts })
end

# Adds a workout to a specific date and redirects to the day view
#
# @param [Integer] session[:id] The ID of the user
# @param [String] date The date to add the workout to
# @param [Integer] workout_id The ID of the workout to add
#
# @see Model#date_add_workout
post('/date/new/:year/:month/:day/:workout_id') do
    year = params[:year]
    month = params[:month]
    day = params[:day]
    workout_id = params[:workout_id]
    date = "#{year}-#{month}-#{day}"
    puts "POST DATE"
    puts date
    puts workout_id

    date_add_workout(session[:id], date, workout_id)
    redirect("/date/#{year}/#{month}/#{day}")
end

# Deletes a workout from a specific date
#
# @param [Integer] session[:id] The ID of the user
# @param [Integer] workout_id The ID of the workout
# @param [String] date The date from which to delete the workout
#
# @see Model#date_delete_workout
post('/date/:year/:month/:day/delete/:workout_id') do
    year = params[:year]
    month = params[:month]
    day = params[:day]
    workout_id = params[:workout_id]
    date = "#{year}-#{month}-#{day}"

    date_delete_workout(session[:id], workout_id, date)
    redirect("/date/#{year}/#{month}/#{day}")
end