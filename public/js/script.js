const openMenu = document.getElementById("open_menu");
const closeMenu = document.getElementById("close_menu");
const navMenu = document.getElementById("nav")


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