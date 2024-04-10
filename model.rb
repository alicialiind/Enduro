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

def create_weight_workout(user_id, title, exercises, time)
    workout_type = "weight"

    db = connect_to_db()
    db.execute("INSERT INTO workouts (user_id, title, duration, workout_type) VALUES (?, ?, ?, ?)", user_id, title, time, workout_type)
    workout_id = db.last_insert_row_id

    exercises.each do |exercise|
        db.execute("INSERT INTO exercises (exercise_name, sets, reps, workout_id) VALUES (?, ?, ?, ?)", exercise[0], exercise[1], exercise[2], workout_id)
    end
end

def get_group_id(workout_id)
    db = connect_to_db()
    first_group_id_result = db.execute("SELECT MIN(group_id) FROM run_details WHERE workout_id = ?", workout_id)
    first_group_id = first_group_id_result.first[0]

    if first_group_id.nil?
        last_group_id_result = db.execute("SELECT MAX(group_id) FROM run_details")
        last_group_id = last_group_id_result.first[0] || 0
        new_group_id = last_group_id + 1

        return new_group_id
    else
        return first_group_id
    end

    return first_group_id
end

def create_easy_run(user_id, title, distance, duration)
    db = connect_to_db()
    workout_type = "easy_run"
    if distance != ""
        attribute_type = "distance"

        db.execute("INSERT INTO workouts (user_id, title, workout_type) VALUES (?, ?, ?)", user_id, title, workout_type)

        workout_id = db.last_insert_row_id
        group_id = get_group_id(workout_id)

        db.execute("INSERT INTO run_details (workout_id, attribute_type, attribute_value, group_id) VALUES (?, ?, ?, ?)", workout_id, attribute_type, distance, group_id)
    elsif duration != ""
        attribute_type = "duration"

        db.execute("INSERT INTO workouts (user_id, title, workout_type, duration) VALUES (?, ?, ?, ?)", user_id, title, workout_type, duration)

        workout_id = db.last_insert_row_id
        group_id = get_group_id(workout_id)

        db.execute("INSERT INTO run_details (workout_id, attribute_type, attribute_value, group_id) VALUES (?, ?, ?, ?)", workout_id, attribute_type, duration, group_id)
    end
end

def create_tempo_run(user_id, title, distances, heart_rate_zones)
    db = connect_to_db()
    workout_type = "tempo_run"

    db.execute("INSERT INTO workouts (user_id, title, workout_type) VALUES (?, ?, ?)", user_id, title, workout_type)
    workout_id = db.last_insert_row_id
    
    group_id = get_group_id(workout_id)

    i = 0
    while i < distances.length
        attribute_type = "distance"
        db.execute("INSERT INTO run_details (workout_id, attribute_type, attribute_value, group_id) VALUES (?, ?, ?, ?)", workout_id, attribute_type, distances[i], group_id)
        
        attribute_type = "heart_rate_zone"
        db.execute("INSERT INTO run_details (workout_id, attribute_type, attribute_value, group_id) VALUES (?, ?, ?, ?)", workout_id, attribute_type, heart_rate_zones[i], group_id)
        group_id += 1
        i += 1
    end
end

def create_interval_run(user_id, title, durations, heart_rate_zones)
    db = connect_to_db()
    workout_type = "interval_run"
    total_time = 0
    durations.each { |a| total_time+=a.to_i }

    db.execute("INSERT INTO workouts (user_id, title, duration, workout_type) VALUES (?, ?, ?, ?)", user_id, title, total_time, workout_type)
    workout_id = db.last_insert_row_id

    group_id = get_group_id(workout_id)
    
    i = 0
    while i < durations.length
        attribute_type = "duration"
        db.execute("INSERT INTO run_details (workout_id, attribute_type, attribute_value, group_id) VALUES (?, ?, ?, ?)", workout_id, attribute_type, durations[i], group_id)
        
        attribute_type = "heart_rate_zone"
        db.execute("INSERT INTO run_details (workout_id, attribute_type, attribute_value, group_id) VALUES (?, ?, ?, ?)", workout_id, attribute_type, heart_rate_zones[i], group_id)
        group_id += 1
        i += 1
    end
end

def get_workout(workout_id)
    db = connect_to_db()
    workout = db.execute("SELECT * FROM workouts WHERE id = ?", workout_id).first

    return workout
end

def get_workout_type(workout_id)
    db = connect_to_db()
    workout_type = db.execute("SELECT workout_type FROM workouts WHERE id = ?", workout_id).first["workout_type"]

    return workout_type
end

def get_exercises(workout_id)
    db = connect_to_db()
    exercises = db.execute("SELECT * FROM exercises WHERE workout_id = ?", workout_id)

    return exercises
end

def get_run_details(workout_id)
    db = connect_to_db()
    run_details = db.execute("SELECT * FROM run_details WHERE workout_id = ?", workout_id)

    return run_details
end

def delete_workout(workout_id)
    db = connect_to_db()
    db.execute("DELETE FROM workouts WHERE id = ?", workout_id)
    db.execute("DELETE FROM exercises WHERE workout_id = ?", workout_id)
    db.execute("DELETE FROM run_details WHERE workout_id = ?", workout_id)
end

def authenticate_workout(workout_id, user_id)
    db = connect_to_db()
    workout_user_id = db.execute("SELECT user_id FROM workouts WHERE id = ?", workout_id).first
    if workout_user_id["user_id"] == session[:id]
        return true
    end
end

def update_easy_run(workout_id, title, distance, duration)
    db = connect_to_db()

    if distance != nil
        db.execute("UPDATE workouts SET title = ? WHERE id = ?", title, workout_id)
        db.execute("UPDATE run_details SET attribute_value = ? WHERE workout_id = ?", distance, workout_id)
    elsif duration != nil
        db.execute("UPDATE workouts SET title = ? WHERE id = ?", title, workout_id)
        db.execute("UPDATE run_details SET attribute_value = ? WHERE workout_id = ?", duration, workout_id)
    end
end

def update_tempo_run(workout_id, title, distances, heart_rate_zones)
    db = connect_to_db()
    group_id = get_group_id(workout_id)
    db.execute("UPDATE workouts SET title = ? WHERE id = ?", title, workout_id)
    
    i = 0
    while i < distances.length
        db.execute("UPDATE run_details SET attribute_value = ? WHERE group_id = ?", distances[i], group_id)
        
        db.execute("UPDATE run_details SET attribute_value = ? WHERE group_id = ?", heart_rate_zones[i], group_id)
        group_id += 1
        i += 1
    end
end

def update_interval_run(workout_id, title, durations, heart_rate_zones)
    db = connect_to_db()
    group_id = get_group_id(workout_id)
    p group_id
    db.execute("UPDATE workouts SET title = ? WHERE id = ?", title, workout_id)
    
    i = 0
    while i < durations.length
        db.execute("UPDATE run_details SET attribute_value = ? WHERE group_id = ?", durations[i], group_id)
        
        db.execute("UPDATE run_details SET attribute_value = ? WHERE group_id = ?", heart_rate_zones[i], group_id)
        group_id += 1
        i += 1
    end
end

def update_weight_workout(workout_id, title, exercises)
    db = connect_to_db()
    db.execute("UPDATE workouts SET title = ?, WHERE id = ?", title, workout_id)
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
    
    schedule_id = db.execute("SELECT id FROM schedules WHERE date = ? AND user_id = ?", date, user_id).first

    p schedule_id

    if schedule_id == nil
        db.execute("INSERT INTO schedules (user_id, date) VALUES (?, ?)", user_id, date)
        schedule_id = db.last_insert_row_id
        puts "inserted date"  
    else
        schedule_id = schedule_id["id"]
    end
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
    workout_ids = db.execute("SELECT id FROM workouts WHERE user_id = ?", user_id)

    p workout_ids
    p user_id

    workout_ids.each do |workout_id|
        db.execute("DELETE FROM workouts_schedules WHERE workout_id = ?", workout_id["id"])
        db.execute("DELETE FROM exercises WHERE workout_id = ?", workout_id["id"])
        db.execute("DELETE FROM run_details WHERE workout_id = ?", workout_id["id"])
    end

    db.execute("DELETE FROM workouts WHERE user_id = ?", user_id)
    db.execute("DELETE FROM users WHERE id = ?", user_id)
end