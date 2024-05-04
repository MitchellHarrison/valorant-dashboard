library(bslib)
library(DT)
library(shiny)

####### constants #######
APP_TITLE <- "Valorant Ranked Tracker"
CURRENT_EPISODE <- 8

###########################
####### START OF UI #######
###########################

ui <- page_navbar(
  title = APP_TITLE,
  sidebar = sidebar(
    width = 300,
    
    # filter games that have vods
    checkboxInput(
      "filter_vod",
      "Only games with a vod",
      value = TRUE
    ),
    
    # map filter
    selectInput(
      "filter_map",
      "Maps:",
      choices = NULL,
      selected = NULL,
      multiple = TRUE
    ),
    
    # agent filter
    selectInput(
      "filter_agent",
      "Agents:",
      choices = NULL,
      selected = NULL,
      multiple = TRUE
    ),
    
    # episode filter
    selectInput(
      "filter_episode",
      "Episode(s):",
      choices = 1:CURRENT_EPISODE,
      selected = CURRENT_EPISODE,
      multiple = TRUE
    ),
    
    # act filter
    selectInput(
      "filter_act",
      "Act(s):",
      choices = 1:3,
      selected = 1:3,
      multiple = TRUE
    )
  ),
  
  ####### SUMMARY PANEL #######
  
  nav_panel(
    title = "Summary"
  ),
  
  ####### DATA PANEL ########
  
  nav_panel(
    title = "Data",
    DTOutput("data_table")
  )
)