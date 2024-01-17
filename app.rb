require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'

enable :sessions

get('/') do 
    slim :start, layout: false
end

get('/login') do 
    slim :login, layout: false
end

post('/login') do
    email = params[:email]
    password = params[:password]

    db = SQLite3::Database.new('db/workout.db')
    db.results_as_hash = true
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

    db = SQLite3::Database.new('db/workout.db')
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
    slim(:myworkouts)
end