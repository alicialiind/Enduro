require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'
require 'date'
require 'time'
require_relative './model.rb'
require 'sinatra/flash'

enable :sessions
set :environment, :development

MAX_ATTEMPTS = 3
INITIAL_COOLDOWN = 2
MAX_COOLDOWN = 300 

before do 
    if !['/', '/login', '/register', '/users/new'].include?(request.path_info) && session[:id].nil?
        redirect('/login')
    end

    if request.path_info == '/admin' && session[:user] != 'admin'
        redirect('/overview')
    end
end

#COOLDOWN FUNCTION

before '/login' do
    session[:attempts] ||= 0
    if session[:attempts] >= MAX_ATTEMPTS
        cooldown = [INITIAL_COOLDOWN * (2 ** (session[:attempts] - MAX_ATTEMPTS)), MAX_COOLDOWN].min
        if Time.now - (session[:last_attempt_time] || Time.now) < cooldown
            halt 429, "Too many attempts. Please wait #{cooldown - (Time.now - session[:last_attempt_time]).to_i} seconds."
        end
    end
end

helpers do
    def get_weekday_from_date(year, month, day)
        date = Date.new(year.to_i, month.to_i, day.to_i)
        return date.strftime('%A')
    end

    def get_month_name(month)
        return Date::MONTHNAMES[month.to_i]
    end

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

    def counter(start_number)
        return start_number += 1
    end
end

get('/') do 
    slim :start, layout: false
end

get('/login') do 
    slim :login, layout: false
end

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

get('/register') do
    slim :register, layout: false
end

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

get('/logout') do
    session.clear
    redirect('/')
end

get('/admin') do
    users = get_all_users()

    slim(:"/admin", locals: { users: users })
end

post('/:user/delete') do
    user_id = params[:user].to_i
    delete_user(user_id)
    redirect('/admin')
end

get('/overview') do
    todays_workouts = get_todays_workouts(session[:id])
    weeks_workouts = get_weeks_workouts(session[:id])

    slim(:overview, locals: { todays_workouts: todays_workouts, weeks_workouts: weeks_workouts })
end

get('/workouts') do 
    workouts = get_workouts(session[:id])

    slim(:"/workouts/index", locals: { workouts: workouts })
end

get('/workouts/new') do 
    slim(:"/workouts/new")
end

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

get('/workouts/:id') do
    workout_id = params[:id].to_i
    workout = get_workout(workout_id);
    exercises = get_exercises(workout_id);

    slim(:"/workouts/show", locals: { workout: workout, exercises: exercises })
end

post('/workouts/:id/delete') do
    workout_id = params[:id].to_i
    if authenticate_workout(workout_id, session[:id])
        delete_workout(workout_id)
    end
    
    redirect('/workouts')
end

get('/workouts/:id/edit') do
    workout_id = params[:id].to_i
    workout_info = get_workout(workout_id)
    workout_type = ""
    exercises = nil
    run_details = nil
    p "----------------"
    p workout_info
    p workout_info["workout_type"]

    if workout_info["workout_type"] == "weight"
        workout_type = "weight"
        exercises = get_exercises(workout_id)
        p exercises
        p "efter slim"
    elsif workout_info["workout_type"] == "easy_run"
        workout_type = "easy_run"
        run_details = get_run_details(workout_id)
    elsif workout_info["workout_type"] == "tempo_run"
        workout_type = "tempo_run"
        run_details = get_run_details(workout_id)
    elsif workout_info["workout_type"] == "interval_run"
        workout_type = "interval_run"
        run_details = get_run_details(workout_id)
    end

    slim(:"/workouts/edit", locals: { workout: workout_info, run_details: run_details, exercises: exercises, workout_type: workout_type })
end

post('/workouts/:id/update') do
    workout_id = params[:id].to_i

    if authenticate_workout(workout_id, session[:id])
        title = params[:title]
        description = params[:description]
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

        update_workout(workout_id, title, description, exercise_tot)
    end
 
    redirect('/workouts')
end

get('/date/:year/:month/:day') do
    year = params[:year]
    month = params[:month]
    day = params[:day]
    date = year + "-" + month + "-" + day

    workouts = date_get_workouts(session[:id], date)
    slim(:"date/show", locals: { year: year, month: month, day: day, workouts: workouts })
end

get('/date/new/:year/:month/:day') do
    year = params[:year]
    month = params[:month]
    day = params[:day]
    date = "#{year}-#{month}-#{day}"

    workouts = get_workouts(session[:id])
    slim(:"date/new", locals: { year: year, month: month, day: day, workouts: workouts })
end

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

post('/date/:year/:month/:day/delete/:workout_id') do
    year = params[:year]
    month = params[:month]
    day = params[:day]
    workout_id = params[:workout_id]
    date = "#{year}-#{month}-#{day}"

    date_delete_workout(session[:id], workout_id, date)
    redirect("/date/#{year}/#{month}/#{day}")
end