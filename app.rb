require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'
require 'date'
require 'time'

enable :sessions

helpers do
    def get_calendar(year, month)
        days = Date.new(year, month, -1).day
        first_day = Date.new(year, month, 1)
        weekday = first_day.cwday
        month_information = [year, Date::MONTHNAMES[month], days, weekday]
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

    db = open_db("db/workout.db")
    result = db.execute("SELECT * FROM users WHERE email = ?", email).first
    pwdigest = result['pwdigest']
    id = result['id']

    if BCrypt::Password.new(pwdigest) == password
        session[:id] = id
        session[:user] = result['name']
        session[:user_email] = email
        
        redirect('/overview')
    else
        puts "Wrong password"
    end
end

get('/register') do
    slim :register, layout: false
end

def image_to_binary(image_path)
    File.open(image_path, 'rb') { |file| file.read }
end

post('/users/new') do 
    firstname = params[:firstname]
    lastname = params[:lastname]
    email = params[:email]
    password = params[:password]
    password_confirm = params[:password_confirm]
    #pfp = params[:pfp]
    name = firstname.strip.capitalize + " " + lastname.strip.capitalize
    puts "--------------------------"
    puts name, email, password, password_confirm

    db = open_db("db/workout.db")
    email_taken = []
    email_taken = db.execute("SELECT COUNT (email) FROM users WHERE email = ?", email)
    puts "before if"
    puts email_taken[0]

    if email_taken[0] != [0]
        puts "Email already in use"
    elsif password == password_confirm
        puts "inside main"
        password_digest = BCrypt::Password.create(password)
        db.execute("INSERT INTO users (name, email, pwdigest) VALUES (?, ?, ?)", name, email, password_digest,)
    else
        puts "Passwords don't match"
    end
    redirect('/login')
end

get('/logout') do
    session.clear
    redirect('/')
end

get('/overview') do
    slim(:overview)
end

get('/myworkouts') do 
    db = open_db("db/workout.db")
    workouts = db.execute("SELECT * FROM workouts")

    slim(:"/workouts/my_workouts", locals: { workouts: workouts })
end

get('/create_new_workout') do 
    slim(:"/workouts/new_workout")
end

post('/workout/new') do 
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

    db = open_db("db/workout.db")
    db.execute("INSERT INTO workouts (user_id, title, description) VALUES (?, ?, ?)", session[:id], title, description)
    workout_id = db.last_insert_row_id

    exercise_tot.each do |exercise|
        db.execute("INSERT INTO exercises (exercise_name, sets, reps, workout_id) VALUES (?, ?, ?, ?)", exercise[0], exercise[1], exercise[2], workout_id)
    end
    
    redirect('/myworkouts')
end

get('/myworkouts/:id') do
    workout_id = params[:id].to_i
    db = open_db("db/workout.db")
    workout = db.execute("SELECT * FROM workouts WHERE id = ?", workout_id).first
    exercises = db.execute("SELECT * FROM exercises WHERE workout_id = ?", workout_id)

    slim(:"/workouts/show_workout", locals: { workout: workout, exercises: exercises })
end

post('/myworkouts/:id/delete') do
    workout_id = params[:id].to_i
    db = open_db("db/workout.db")
    db.execute("DELETE FROM workouts WHERE id = ?", workout_id)
    db.execute("DELETE FROM exercises WHERE workout_id = ?", workout_id)

    redirect('/myworkouts')
end

get('/myworkouts/:id/edit') do
    workout_id = params[:id].to_i
    db = open_db("db/workout.db")
    workout_info = db.execute("SELECT * FROM workouts WHERE id = ?", workout_id).first
    exercises = db.execute("SELECT * FROM exercises WHERE workout_id = ?", workout_id)

    slim(:"/workouts/edit_workout", locals: { workout: workout_info, exercises: exercises })
end

post('/myworkouts/:id/update') do
    id = params[:id].to_i
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

    db = open_db("db/workout.db")
    db.execute("UPDATE workouts SET title = ?, description = ? WHERE id = ?", title, description, id)

    exercise_ids = db.execute("SELECT id FROM exercises WHERE workout_id = ?", id)

    i = 0
    exercise_tot.each do |exercise|
        exercise_id = exercise_ids[i]["id"]
        db.execute("UPDATE exercises SET exercise_name = ?, sets = ?, reps = ? WHERE id = ?", exercise[0], exercise[1], exercise[2], exercise_id)
        i += 1
    end
    
    redirect('/myworkouts')
end