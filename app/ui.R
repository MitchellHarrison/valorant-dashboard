library(bslib)
library(DT)
library(shiny)
library(thematic)
library(plotly)
thematic_shiny(font = "auto")

####### constants #######
APP_TITLE <- "Valorant Ranked Tracker"
BW_THEME <- "zephyr"
VAL_BLACK <- "#0F1923"

theme <- bs_theme(bootswatch = BW_THEME, fg = VAL_BLACK, bg = "#fff")

###########################
####### START OF UI #######
###########################

ui <- page_navbar(
  theme = theme,
  title = APP_TITLE,
  sidebar = sidebar(
    width = 300,
    
    # filter games that have vods
    checkboxInput(
      "filter_vod",
      "Only games with a vod",
      value = FALSE
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
      choices = NULL,
      selected = NULL,
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
    title = "Summary",
    fluidRow(
      column(
        width = 6,
        card(
          height = 300,
          plotOutput("plt_winrate"),
        ),
        # textOutput("most_played_agent"),
        # textOutput("top_agent_game_count"),
        # textOutput("top_agent_winrate")
        card(plotOutput("plt_headshot_kdr"))
      ),
      column(
        width = 6,
        card(plotOutput("plt_map_kdr")),
        card(
          height = 300,
          plotOutput("plt_dmg_delta")
        )
      )
    )
  ),
  
  ####### DATA PANEL ########
  
  nav_panel(
    title = "Data",
    DTOutput("data_table")
  )
)