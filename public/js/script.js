const newExerciseButton = document.getElementById("add_new_exercise_button");
const exerciseContainer = document.getElementById("exercises");
const newTempoButton = document.getElementById("add_new_tempo_button");
const tempoContainer = document.getElementById("tempo_container");
const newIntervalButton = document.getElementById("add_new_interval_button");
const intervalContainer = document.getElementById("interval_container");

const calendarTitle = document.getElementById("calendar_title");
const leftArrow = document.getElementById("left_calendar_arrow");
const rightArrow = document.getElementById("right_calendar_arrow");
const weightCheckbox = document.getElementById("weight_type");
const runCheckbox = document.getElementById("run_type");
const easyRunCheckbox = document.getElementById("easy_run_type");
const tempoRunCheckbox = document.getElementById("tempo_run_type");
const intervalRunCheckbox = document.getElementById("interval_run_type");
let isWeightTraining = false;
let isRunTraining = false;
let isEasyRun = false;
let isTempoRun = false;
let isIntervalRun = false;
const weightTrainingExercises = document.getElementById("weight_training");
const typeOfRun = document.getElementById("type_of_run");
const easyRun = document.getElementById("easy_run");
const tempoRun = document.getElementById("tempo_run");
const intervalRun = document.getElementById("interval_run");

const months = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
];
const d = new Date();

let year = d.getFullYear();
let month = months[d.getMonth()];

document.addEventListener("DOMContentLoaded", (event) => {
  calendarTitle.innerHTML = year + " " + month;
});

function addExercise() {
  let newExercise = document.createElement("div");
  newExercise.innerHTML = `
        <input type="text" name="exercise[]" placeholder="exercise"/>
        <input type="number" name="sets[]" placeholder="sets"/>
        <input type="number" name="reps[]" placeholder="reps"/>
    `;
  exerciseContainer.appendChild(newExercise);
}

function addTempo() {
  let newTempo = document.createElement("div");
  newTempo.innerHTML = `
    <div class="input-blocks">
      <div class="label-input">
        <label for="time">Distance (km)</label>
        <input type="text" id="time" name="tempo_distance[]" placeholder="Distance"/>
      </div>
      <div class="label-input">
        <label for="time">Heart Rate Zone</label>
        <input type="text" id="time" name="tempo_heart[]" placeholder="Heart Rate Zone"/>
      </div>
    </div>
  `;
  tempoContainer.appendChild(newTempo);
}

function addInterval() {
  let newInterval = document.createElement("div");
  newInterval.innerHTML = `
    <div class="input-blocks">
      <div class="label-input">
        <label for="time">Time (min)</label>
        <input type="text" id="time" name="interval_time[]" placeholder="Time"/>
      </div>
      <div class="label-input">
        <label for="time">Heart Rate Zone</label>
        <input type="text" id="time" name="interval_heart[]" placeholder="Heart Rate Zone"/>
      </div>
    </div>
  `;
  intervalContainer.appendChild(newInterval);
}

newExerciseButton.addEventListener("click", addExercise);
newTempoButton.addEventListener("click", addTempo);
newIntervalButton.addEventListener("click", addInterval);

function handleWeightChecked() {
  isWeightTraining = weightCheckbox.checked;
  if (isWeightTraining && isRunTraining) {
    runCheckbox.checked = false;
  }
  if (isWeightTraining) {
    weightTrainingExercises.style.display = "block";
    typeOfRun.style.display = "none";
    easyRun.style.display = "none";
    tempoRun.style.display = "none";
    intervalRun.style.display = "none";
    easyRunCheckbox.checked = false;
    tempoRunCheckbox.checked = false;
    intervalRunCheckbox.checked = false;
    isEasyRun = false;
    isTempoRun = false;
    isIntervalRun = false;
  } else {
    weightTrainingExercises.style.display = "none";
  }
}

function handleRunChecked() {
  isRunTraining = runCheckbox.checked;
  if (isRunTraining && isWeightTraining) {
    weightCheckbox.checked = false;
  }

  if (isRunTraining) {
    typeOfRun.style.display = "flex";
    weightTrainingExercises.style.display = "none";
  } else {
    typeOfRun.style.display = "none";
  }
}

function handleEasyRunChecked() {
  isEasyRun = easyRunCheckbox.checked;
  if ((isEasyRun && isTempoRun) || (isEasyRun && isIntervalRun)) {
    tempoRunCheckbox.checked = false;
    intervalRunCheckbox.checked = false;
  }

  if (isEasyRun) {
    easyRun.style.display = "block";
    tempoRun.style.display = "none";
    intervalRun.style.display = "none";
  } else {
    easyRun.style.display = "none";
  }
}

function handleTempoRunChecked() {
  isTempoRun = tempoRunCheckbox.checked;
  if ((isEasyRun && isTempoRun) || (isTempoRun && isIntervalRun)) {
    easyRunCheckbox.checked = false;
    intervalRunCheckbox.checked = false;
  }

  if (isTempoRun) {
    easyRun.style.display = "none";
    tempoRun.style.display = "block";
    intervalRun.style.display = "none";
  } else {
    tempoRun.style.display = "none";
  }
}

function handleIntervalRunChecked() {
  isIntervalRun = intervalRunCheckbox.checked;
  if ((isIntervalRun && isTempoRun) || (isEasyRun && isIntervalRun)) {
    tempoRunCheckbox.checked = false;
    easyRunCheckbox.checked = false;
  }

  if (isIntervalRun) {
    easyRun.style.display = "none";
    tempoRun.style.display = "none";
    intervalRun.style.display = "block";
  } else {
    intervalRun.style.display = "none";
  }
}

weightCheckbox.addEventListener("click", handleWeightChecked);
runCheckbox.addEventListener("click", handleRunChecked);
easyRunCheckbox.addEventListener("click", handleEasyRunChecked);
tempoRunCheckbox.addEventListener("click", handleTempoRunChecked);
intervalRunCheckbox.addEventListener("click", handleIntervalRunChecked);
