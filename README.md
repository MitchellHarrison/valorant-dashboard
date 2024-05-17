# Local hosting instructions (for development)
This project relies on an email address that is stored in an `.Renviron` file.
This email is used to authenticate your G-mail account, allowing a user to read
the data from Google Sheets. Without this authentication, the app will not work.
The app is also hosted publicly
(here)[https://qmre3f-mitch0harrison.shinyapps.io/valorant-dashboard/]. Local
hosting is only required during development.

### Edit `.Renviron.example`
In the file `.Renviron.example`, replace `yourEmailHere@gmail.com` with your
G-mail email address. Note that there should be an empty line at the end of the
file, and no quotation marks etc. should be used.

### Rename `.Renviron.example`
For your R Studio session to read your email, rename the `.Renviron.example` 
file to `.Renviron`.

### Authenticate in-app
In `server.R`, there is a line commented out that contains `gs4_auth()`. 
Un-comment that file and run the app once. There should be a prompt that pops up
in your browser asking you to authenticate with your G-mail account. After that,
`gs4_auth()` can be commented out for the remainder of development.
