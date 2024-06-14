require 'sinatra'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'

module Model

    # Establishes a connection to the SQLite3 database
    #
    # @return [SQLite3::Database] a SQLite3 database instance with results formatted as hashes
    def connect_to_db()
        db = SQLite3::Database.new('db/workout.db')
        db.results_as_hash = true
        return db
    end

    # Registers a new user with the provided credentials
    #
    # @param [String] name, The name of the user
    # @param [String] email, The email of the user
    # @param [String] password, The intended password
    # @param [String] password_confirm, The password confirmation
    #
    # @return [void]
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

    # Finds a user by their email
    #
    # @param [String] email, The email of the user to find
    #
    # @return [Hash, nil] the first user matching the email or nil if no user is found
    def find_user_by_email(email)
        db = connect_to_db()
        result = db.execute("SELECT * FROM users WHERE email = ?", email).first
        return result
    end

    # Authenticates a user given a password and a password digest
    #
    # @param [String] password, The password to verify
    # @param [String] pwdigest, The password digest to verify against
    #
    # @return [Boolean] true if the password matches the digest, false otherwise
    def authenticate_user(password, pwdigest)
        BCrypt::Password.new(pwdigest) == password
    end

    def authenticate_admin(username)
        return username == 'admin'
    end

    # Retrieves all workouts for the current user on today's date
    #
    # @param [Integer] user_id the ID of the user
    #
    # @return [Array] an array of workouts scheduled for today
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

    # Retrieves all workouts for the current user for the current week
    #
    # @param [Integer] user_id, The ID of the user
    #
    # @return [Array] an array of workouts scheduled for the current week
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

    # Retrieves all workouts for a specific user
    #
    # @param [Integer] user_id, The ID of the user
    #
    # @return [Array] A list of workouts associated with the user
    def get_workouts(user_id)
        db = connect_to_db()
        workouts = db.execute("SELECT * FROM workouts WHERE user_id = ?", user_id)

        return workouts
    end

    # Creates a weight workout for a user with specified exercises and duration
    #
    # @param [Integer] user_id, The ID of the user
    # @param [String] title, The title of the workout
    # @param [Array] exercises, List of exercises including name, sets, and reps
    # @param [Integer] time, The duration of the workout
    #
    # @return [void]
    def create_weight_workout(user_id, title, exercises, time)
        workout_type = "weight"

        db = connect_to_db()
        db.execute("INSERT INTO workouts (user_id, title, duration, workout_type) VALUES (?, ?, ?, ?)", user_id, title, time, workout_type)
        workout_id = db.last_insert_row_id

        exercises.each do |exercise|
            db.execute("INSERT INTO exercises (exercise_name, sets, reps, workout_id) VALUES (?, ?, ?, ?)", exercise[0], exercise[1], exercise[2], workout_id)
        end
    end

    # Retrieves the group ID for the first group of a workout or creates a new one if not present
    #
    # @param [Integer] workout_id, The ID of the workout
    #
    # @return [Integer] The group ID associated with the workout
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

    # Creates an easy run workout entry, setting either distance or duration based on which is provided
    #
    # @param [Integer] user_id, The ID of the user
    # @param [String] title, The title of the workout
    # @param [String] distance, The distance for the run
    # @param [String] duration, The duration of the run
    #
    # @return [void]
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

    # Creates a tempo run workout with multiple segments of distances and heart rate zones
    #
    # @param [Integer] user_id, The ID of the user
    # @param [String] title, The title of the workout
    # @param [Array] distances, A list of distances for each segment of the run
    # @param [Array] heart_rate_zones, A list of heart rate zones for each segment
    #
    # @return [void]
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

    # Creates an interval run workout with multiple segments of durations and heart rate zones
    #
    # @param [Integer] user_id, The ID of the user
    # @param [String] title, The title of the workout
    # @param [Array] durations, A list of durations for each interval
    # @param [Array] heart_rate_zones, A list of heart rate zones for each interval
    #
    # @return [void]
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

    # Retrieves a single workout by its ID
    #
    # @param [Integer] workout_id, The ID of the workout to retrieve
    #
    # @return [Hash] The workout details
    def get_workout(workout_id)
        db = connect_to_db()
        workout = db.execute("SELECT * FROM workouts WHERE id = ?", workout_id).first

        return workout
    end

    # Retrieves the type of a specific workout by its ID
    #
    # @param [Integer] workout_id, The ID of the workout
    #
    # @return [String] The type of the workout
    def get_workout_type(workout_id)
        db = connect_to_db()
        workout_type = db.execute("SELECT workout_type FROM workouts WHERE id = ?", workout_id).first["workout_type"]

        return workout_type
    end

    # Retrieves all exercises associated with a specific workout by its ID
    #
    # @param [Integer] workout_id, The ID of the workout
    #
    # @return [Array] List of exercises for the workout
    def get_exercises(workout_id)
        db = connect_to_db()
        exercises = db.execute("SELECT * FROM exercises WHERE workout_id = ?", workout_id)

        return exercises
    end

    # Retrieves all running details associated with a specific workout by its ID
    #
    # @param [Integer] workout_id, The ID of the workout
    #
    # @return [Array] List of running details for the workout
    def get_run_details(workout_id)
        db = connect_to_db()
        run_details = db.execute("SELECT * FROM run_details WHERE workout_id = ?", workout_id)

        return run_details
    end

    # Deletes a workout and its associated exercises and running details by its ID
    #
    # @param [Integer] workout_id, The ID of the workout to delete
    #
    # @return [void]
    def delete_workout(workout_id)
        db = connect_to_db()
        db.execute("DELETE FROM workouts WHERE id = ?", workout_id)
        db.execute("DELETE FROM exercises WHERE workout_id = ?", workout_id)
        db.execute("DELETE FROM run_details WHERE workout_id = ?", workout_id)
    end

    # Authenticates that a workout belongs to a specific user
    #
    # @param [Integer] workout_id, The ID of the workout
    # @param [Integer] user_id, The ID of the user to authenticate against
    #
    # @return [Boolean] True if the workout belongs to the user, false otherwise
    def authenticate_workout(workout_id, user_id)
        db = connect_to_db()
        workout_user_id = db.execute("SELECT user_id FROM workouts WHERE id = ?", workout_id).first
        if workout_user_id["user_id"] == user_id
            return true
        end
    end

    # Updates the title and either distance or duration of an easy run workout
    #
    # @param [Integer] workout_id, The ID of the workout to update
    # @param [String] title, The new title of the workout
    # @param [String] distance, The new distance to update (if applicable)
    # @param [String] duration, The new duration to update (if applicable)
    #
    # @return [void
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

    # Updates a tempo run workout with new distances and heart rate zones
    #
    # @param [Integer] workout_id, The ID of the workout to update
    # @param [String] title, The new title of the workout
    # @param [Array] distances, List of new distances to update
    # @param [Array] heart_rate_zones, List of new heart rate zones to update
    #
    # @return [void]
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

    # Updates an interval run workout with new durations and heart rate zones
    #
    # @param [Integer] workout_id, The ID of the workout to update
    # @param [String] title, The new title of the workout
    # @param [Array] durations, List of new durations to update
    # @param [Array] heart_rate_zones, List of new heart rate zones to update
    #
    # @return [void]
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

    # Updates a weight workout with new exercises
    #
    # @param [Integer] workout_id, The ID of the workout to update
    # @param [String] title, The new title of the workout
    # @param [Array] exercises, List of exercises with names, sets, and reps to update
    #
    # @return [void]
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

    # Retrieves all workouts for a user on a specific date
    #
    # @param [Integer] user_id, The ID of the user
    # @param [String] date, The date for which to retrieve workouts
    #
    # @return [Array] List of workouts on the specified date
    def date_get_workouts(user_id, date)
        db = connect_to_db()
        workouts = db.execute("SELECT w.* FROM workouts w
        JOIN workouts_schedules ws ON w.id = ws.workout_id
        JOIN schedules s ON ws.schedule_id = s.id
        WHERE s.date = ? AND s.user_id = ?", [date, user_id])

        return workouts
    end

    # Adds a workout to a user's schedule on a specific date
    #
    # @param [Integer] user_id, The ID of the user
    # @param [String] date, The date to add the workout
    # @param [Integer] workout_id, The ID of the workout to add
    #
    # @return [void]
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

    # Deletes a workout from a user's schedule on a specific date
    #
    # @param [Integer] user_id, The ID of the user
    # @param [Integer] workout_id, The ID of the workout to delete
    # @param [String] date, The date from which to delete the workout
    #
    # @return [void]
    def date_delete_workout(user_id, workout_id, date)
        if authenticate_workout(workout_id, user_id)
            db = connect_to_db()
            date_id = db.execute("SELECT id FROM schedules WHERE date = ? AND user_id = ?", date, user_id).first
            p "DATE ID: #{date_id}"
            db.execute("DELETE FROM workouts_schedules WHERE workout_id = ? AND schedule_id = ?", workout_id, date_id["id"])
        end
    end

    # Retrieves all registered users
    #
    # @return [Array] List of all users
    def get_all_users()
        db = connect_to_db()
        users = db.execute("SELECT * FROM users")

        return users
    end

    # Deletes a user and all associated data (workouts, schedules, exercises)
    #
    # @param [Integer] user_id, The ID of the user to delete
    #
    # @return [void]
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
end