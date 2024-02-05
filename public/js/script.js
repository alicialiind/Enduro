const openMenu = document.getElementById("open_menu");
const closeMenu = document.getElementById("close_menu");
const navMenu = document.getElementById("nav")
const newExerciseButton = document.getElementById("add_new_exercise_button")
const exerciseContainer = document.getElementById("exercises")
const calendarTitle = document.getElementById("calendar_title")
const leftArrow = document.getElementById("left_calendar_arrow")
const rightArrow = document.getElementById("right_calendar_arrow")

const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const d = new Date()

let year = d.getFullYear()
let month = months[d.getMonth()]

document.addEventListener('DOMContentLoaded', (event) => {
    calendarTitle.innerHTML = year + " " + month;
})

function openNav() {
    navMenu.classList.add("show-nav");
    console.log("open")
    console.log(navMenu)
    openMenu.style.display = "none"
}

function closeNav() {
    navMenu.classList.remove("show-nav");
    console.log("close")
    console.log(navMenu)
    openMenu.style.display = "block"
}

openMenu.addEventListener('click', openNav())
closeMenu.addEventListener('click', closeNav())

function addExercise() {
    let newExercise = document.createElement('div');
    newExercise.innerHTML = `
        <input type="text" name="exercise[]" placeholder="exercise">
        <input type="number" name="sets[]" placeholder="sets">
        <input type="number" name="reps[]" placeholder="reps">
    `
    exerciseContainer.appendChild(newExercise)
}

newExerciseButton.addEventListener('click', addExercise)

