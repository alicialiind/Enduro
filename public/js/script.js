const newExerciseButton = document.getElementById("add_new_exercise_button");
const exerciseContainer = document.getElementById("exercises");
const calendarTitle = document.getElementById("calendar_title");
const leftArrow = document.getElementById("left_calendar_arrow");
const rightArrow = document.getElementById("right_calendar_arrow");
const weightCheckbox = document.getElementById("weight_type");
const runCheckbox = document.getElementById("run_type");
let isWeightTraining = false;
let isRunTraining = false;
const weightTrainingExercises = document.getElementById("weight_training");
const typeOfRun = document.getElementById("type_of_run");

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
        <input type="text" name="exercise[]" placeholder="exercise">
        <input type="number" name="sets[]" placeholder="sets">
        <input type="number" name="reps[]" placeholder="reps">
    `;
  exerciseContainer.appendChild(newExercise);
}

newExerciseButton.addEventListener("click", addExercise);

console.log(weightCheckbox.checked);
console.log(runCheckbox.checked);

function handleWeightChecked() {
  isWeightTraining = weightCheckbox.checked;
  console.log("is weight training: ", isWeightTraining);

  if (isWeightTraining && isRunTraining) {
    runCheckbox.checked = false;
  }

  if (isWeightTraining) {
    weightTrainingExercises.style.display = "block";
    typeOfRun.style.display = "none";
  }
}

function handleRunChecked() {
  isRunTraining = runCheckbox.checked;
  console.log("is run training: ", isRunTraining);

  if (isRunTraining && isWeightTraining) {
    weightCheckbox.checked = false;
  }

  if (isRunTraining) {
    typeOfRun.style.display = "flex";
    weightTrainingExercises.style.display = "none";
  }
}

weightCheckbox.addEventListener("click", handleWeightChecked);
runCheckbox.addEventListener("click", handleRunChecked);
