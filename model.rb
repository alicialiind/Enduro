require 'sinatra'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'
require 'sinatra/flash'

def connect_to_db()
    db = SQLite3::Database.new('db/workout.db')
    db.results_as_hash = true
    return db
end

def register_user(name, email, password, password_confirm)
    db = connect_to_db()
    email_taken = db.execute("SELECT COUNT (email) AS email_count FROM users WHERE email = ?", email)

    if email_taken.first['email_count'] > 0
        p "Email already in use"
    elsif password == password_confirm
        password_digest = BCrypt::Password.create(password)
        db.execute("INSERT INTO users (name, email, pwdigest) VALUES (?, ?, ?)", name, email, password_digest,)
    else
        p "Passwords don't match"
    end
end

def find_user_by_email(email)
    db = connect_to_db()
    result = db.execute("SELECT * FROM users WHERE email = ?", email).first
    return result
end

def authenticate_user(password, pwdigest)
    BCrypt::Password.new(pwdigest) == password
end

def get_todays_workouts(user_id)
    db = connect_to_db()

    todays_date = get_todays_date()
    todays_date_str = "#{todays_date[3]}-#{todays_date[1]}-#{todays_date[0]}"

    todays_workouts = db.execute("SELECT w.* FROM workouts w
    JOIN workouts_schedules ws ON w.id = ws.workout_id
    JOIN schedules s ON ws.schedule_id = s.id
    WHERE s.date = ? AND s.user_id = ?", [todays_date_str, user_id])

    return todays_workouts
end

def get_weeks_workouts(user_id)
    db = connect_to_db()
    today = Date.today
    week_start = today - (today.wday - 1) % 7
    week_end = week_start + 6
    week_start_str = week_start.strftime("%Y-%-m-%-d")
    week_end_str = week_end.strftime("%Y-%-m-%-d")
    p week_start_str, week_end_str

    weeks_workouts = db.execute("SELECT w.* FROM workouts w
    JOIN workouts_schedules ws ON w.id = ws.workout_id
    JOIN schedules s ON ws.schedule_id = s.id
    WHERE s.date BETWEEN ? AND ? AND s.user_id = ?", [week_start_str, week_end_str, user_id])

    return weeks_workouts
end

def get_workouts(user_id)
    db = connect_to_db()
    workouts = db.execute("SELECT * FROM workouts WHERE user_id = ?", user_id)

    return workouts
end

def create_workout(user_id, title, desc, exercises)
    db = connect_to_db()
    db.execute("INSERT INTO workouts (user_id, title, description) VALUES (?, ?, ?)", user_id, title, desc)
    workout_id = db.last_insert_row_id

    exercises.each do |exercise|
        db.execute("INSERT INTO exercises (exercise_name, sets, reps, workout_id) VALUES (?, ?, ?, ?)", exercise[0], exercise[1], exercise[2], workout_id)
    end
end

def get_workout(workout_id)
    db = connect_to_db()
    workout = db.execute("SELECT * FROM workouts WHERE id = ?", workout_id).first

    return workout
end

def get_exercises(workout_id)
    db = connect_to_db()
    exercises = db.execute("SELECT * FROM exercises WHERE workout_id = ?", workout_id)

    return exercises
end

def delete_workout(workout_id)
    db = connect_to_db()
    db.execute("DELETE FROM workouts WHERE id = ?", workout_id)
    db.execute("DELETE FROM exercises WHERE workout_id = ?", workout_id)
end

def authenticate_workout(workout_id, user_id)
    db = connect_to_db()
    workout_user_id = db.execute("SELECT user_id FROM workouts WHERE id = ?", workout_id).first
    if workout_user_id["user_id"] == session[:id]
        return true
    end
end

def update_workout(workout_id, title, desc, exercises)
    db = connect_to_db()
    db.execute("UPDATE workouts SET title = ?, description = ? WHERE id = ?", title, desc, workout_id)
    exercise_ids = db.execute("SELECT id FROM exercises WHERE workout_id = ?", workout_id)

    i = 0
    exercises.each do |exercise|
        exercise_id = exercise_ids[i]["id"]
        db.execute("UPDATE exercises SET exercise_name = ?, sets = ?, reps = ? WHERE id = ?", exercise[0], exercise[1], exercise[2], exercise_id)
        i += 1
    end
end

def date_get_workouts(user_id, date)
    db = connect_to_db()
    workouts = db.execute("SELECT w.* FROM workouts w
    JOIN workouts_schedules ws ON w.id = ws.workout_id
    JOIN schedules s ON ws.schedule_id = s.id
    WHERE s.date = ? AND s.user_id = ?", [date, user_id])

    return workouts
end

def date_add_workout(user_id, date, workout_id)
    db = connect_to_db()
    db.execute("INSERT INTO schedules (user_id, date) VALUES (?, ?) ON CONFLICT (date) DO NOTHING", user_id, date)

    puts "inserted date"

    schedule_id = db.execute("SELECT id FROM schedules WHERE date = ?", date).first["id"]

    puts "Aquired schedule_id"
    puts schedule_id

    db.execute("INSERT INTO workouts_schedules (workout_id, schedule_id) VALUES (?, ?)", workout_id, schedule_id)
end

def date_delete_workout(user_id, workout_id, date)
    if authenticate_workout(workout_id, user_id)
        db = connect_to_db()
        date_id = db.execute("SELECT id FROM schedules WHERE date = ? AND user_id = ?", date, user_id).first
        p "DATE ID: #{date_id}"
        db.execute("DELETE FROM workouts_schedules WHERE workout_id = ? AND schedule_id = ?", workout_id, date_id["id"])
    end
end

def get_all_users()
    db = connect_to_db()
    users = db.execute("SELECT * FROM users")

    return users
end

def delete_user(user_id)
    db = connect_to_db()
    db.execute("DELETE FROM schedules WHERE user_id = ?", user_id)
    workout_ids = db.execute("SELECT * FROM workouts WHERE user_id = ?", user_id).fetchall()

    workout_ids.each do |workout|
        db.execute("DELETE FROM workouts_schedules WHERE workout_id = ?", workout_id)
        db.execute("DELETE FROM exercises WHERE workout_id = ?", workout_id)
    end

    db.execute("DELETE FROM workouts WHERE user_id = ?", user_id)
    db.execute("DELETE FROM users WHERE user_id = ?", user_id)
    
end