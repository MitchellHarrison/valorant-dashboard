library(DT)
library(googlesheets4)
library(shiny)
library(tidyverse)
library(yaml)

# authenticating with Google
# should only be necessary once, but no need to comment out these lines
SECRETS <- read_yaml("../secrets.yaml")
AUTH_EMAIL <- SECRETS$EMAIL
gs4_auth(email = AUTH_EMAIL)

# read data from Google Sheets
DATA_URL <- paste0(
  "https://docs.google.com/spreadsheets/d/1EdN0USO2oTRaY77LUpduruFPNn",
  "_00L8Ea8wjGBiZybY/edit?usp=sharing"
)
data <- read_sheet(DATA_URL)

###############################
####### START OF SERVER #######
###############################

server <- function(input, output, session) {
  
  ####### FILTER DATA USING SIDEBAR FILTERS #######
  
  sel_data <- reactive({
    sel <- data |>
      filter(
        map %in% input$filter_map,
        agent %in% input$filter_agent,
        episode %in% input$filter_episode,
        act %in% input$filter_act
      )
    if (input$filter_vod) {
      sel <- filter(sel, !is.na(vod))
    }
    sel
  })
  
  ####### DYNAMIC FILTER OPTIONS BASED ON DATA #######
  
  observe({
    updateSelectInput(
      session, 
      "filter_map", 
      choices = sort(unique(data$map)),
      selected = sort(unique(data$map))
    )
  })
  
  observe({
    updateSelectInput(
      session, 
      "filter_agent", 
      choices = sort(unique(data$agent)),
      selected = sort(unique(data$agent))
    )
  })
  
  observe({
    updateSelectInput(
      session,
      "filter_episode", 
      choices = sort(unique(data$episode)),
      selected = sort(unique(data$episode))
    )
  })
  
  observe({
    updateSelectInput(
      session,
      "filter_act", 
      choices = sort(unique(data$act)),
      selected = sort(unique(data$act))
    )
  })
  
  ####### DATA TAB ELEMENTS #######
  
  output$data_table <- renderDT(
    sel_data(),
    options = list(scrollX = TRUE)
  )
}