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
    p "---------------"
    p title
    p description
    p exercises
    p sets
    p reps

end