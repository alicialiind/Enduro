require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'
require 'date'
require 'time'
require_relative './model.rb'

enable :sessions
set :environment, :development

before do 
    if !['/', '/login', '/register', '/users/new'].include?(request.path_info) && session[:id].nil?
        redirect('/login')
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

def open_db(path)
    db = SQLite3::Database.new('db/workout.db')
    db.results_as_hash = true
    return db
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

    create_workout(session[:id], title, description, exercise_tot)
    
    redirect('/workouts')
end

get('/workouts/:id') do
    workout_id = params[:id].to_i
    db = open_db("db/workout.db")
    workout = get_workout(workout_id);
    exercises = get_exercises(workout_id);

    slim(:"/workouts/show", locals: { workout: workout, exercises: exercises })
end

post('/workouts/:id/delete') do
    workout_id = params[:id].to_i
    db = open_db("db/workout.db")
    workout_user_id = db.execute("SELECT user_id FROM workouts WHERE id = ?", workout_id).first

    if workout_user_id["user_id"] == session[:id]
        db.execute("DELETE FROM workouts WHERE id = ?", workout_id)
        db.execute("DELETE FROM exercises WHERE workout_id = ?", workout_id)
    end
    redirect('/workouts')
end

get('/workouts/:id/edit') do
    workout_id = params[:id].to_i
    db = open_db("db/workout.db")
    workout_info = db.execute("SELECT * FROM workouts WHERE id = ?", workout_id).first
    exercises = db.execute("SELECT * FROM exercises WHERE workout_id = ?", workout_id)

    slim(:"/workouts/edit", locals: { workout: workout_info, exercises: exercises })
end

post('/workouts/:id/update') do
    id = params[:id].to_i
    db = open_db("db/workout.db")
    workout_user_id = db.execute("SELECT user_id FROM workouts WHERE id = ?", id).first

    if workout_user_id["user_id"] == session[:id]
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

        db.execute("UPDATE workouts SET title = ?, description = ? WHERE id = ?", title, description, id)

        exercise_ids = db.execute("SELECT id FROM exercises WHERE workout_id = ?", id)

        i = 0
        exercise_tot.each do |exercise|
            exercise_id = exercise_ids[i]["id"]
            db.execute("UPDATE exercises SET exercise_name = ?, sets = ?, reps = ? WHERE id = ?", exercise[0], exercise[1], exercise[2], exercise_id)
            i += 1
        end
    end
 
    redirect('/workouts')
end

get('/date/:year/:month/:day') do
    year = params[:year]
    month = params[:month]
    day = params[:day]
    date = year + "-" + month + "-" + day
    puts "DATE"
    puts date

    db = open_db("db/workout.db")
    workouts = db.execute("SELECT w.* FROM workouts w
    JOIN workouts_schedules ws ON w.id = ws.workout_id
    JOIN schedules s ON ws.schedule_id = s.id
    WHERE s.date = ? AND s.user_id = ?", [date, session[:id]])

    slim(:"date/show", locals: { year: year, month: month, day: day, workouts: workouts })
end

get('/date/new/:year/:month/:day') do
    year = params[:year]
    month = params[:month]
    day = params[:day]
    date = "#{year}-#{month}-#{day}"

    db = open_db("db/workout.db")
    workouts = db.execute("SELECT * FROM workouts WHERE user_id = ?", session[:id])

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

    db = open_db("db/workout.db")
    db.execute("INSERT INTO schedules (user_id, date) VALUES (?, ?) ON CONFLICT (date) DO NOTHING", session[:id], date)

    puts "inserted date"

    schedule_id = db.execute("SELECT id FROM schedules WHERE date = ?", date).first["id"]

    puts "Aquired schedule_id"
    puts schedule_id

    db.execute("INSERT INTO workouts_schedules (workout_id, schedule_id) VALUES (?, ?)", workout_id, schedule_id)


    redirect("/date/#{year}/#{month}/#{day}")
end

post('/date/:year/:month/:day/delete/:workout_id') do
    year = params[:year]
    month = params[:month]
    day = params[:day]
    workout_id = params[:workout_id]
    date = "#{year}-#{month}-#{day}"

    db = open_db("db/workout.db")
    date_id = db.execute("SELECT id FROM schedules WHERE date = ? AND user_id = ?", date, session[:id]).first
    p "DATE ID: #{date_id}"
    db.execute("DELETE FROM workouts_schedules WHERE workout_id = ? AND schedule_id = ?", workout_id, date_id["id"])
    
    redirect("/date/#{year}/#{month}/#{day}")
end