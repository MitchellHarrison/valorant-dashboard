library(bslib)
library(colorspace)
library(DT)
library(glue)
library(googlesheets4)
library(janitor)
library(plotly)
library(pROC)
library(shiny)
library(shinyBS)
library(thematic)
library(tidymodels)
library(tidyverse)
library(yaml)
set.seed(8012017)

PLOT_FONT_SIZE <- 15
PLOT_FONT <- list(family = "Inter")
VAL_RED <- "#FF4655"
VAL_BLACK <- "#0F1923"

color_line <- VAL_RED
color_loss <- VAL_RED
color_win <- VAL_BLACK
pal_win_loss <- c("Win" = color_win, "Loss" = color_loss)
model_options <- c("Agent" = "agent", "Map" = "map", "Kills" = "kills", 
                   "Deaths" = "deaths", "Assists" = "assists", 
                   "K/D Ratio" = "kdr", "Avg. Damage Delta" = "avg_dmg_delta", 
                   "Headshot %" = "headshot_pct", "Avg. Damage" = "avg_dmg", 
                   "ACS" = "acs", "Frag Number" = "num_frag")
PLT_NO_DATA <- ggplot() +
  annotate(
    geom = "text", 
    x = 0, 
    y = 0, 
    label = "No data available with these filters.",
    size = 7
    ) +
  theme_void()
  
####### authenticating with Google #######
# Run gs4_auth() once, authenticate using the browser window that appears,
# and if the app runs for you, you can permanently re-comment it out.

options(gargle_oauth_cache = ".secrets") # for authentication
# gs4_auth() # comment out if app is working
gs4_deauth()
gs4_auth(cache = ".secrets", email = Sys.getenv("EMAIL"))

# read data from Google Sheets
DATA_URL <- paste0(
  "https://docs.google.com/spreadsheets/d/1EdN0USO2oTRaY77LUpduruFPNn",
  "_00L8Ea8wjGBiZybY/edit?usp=sharing"
)
data <- read_sheet(DATA_URL) |>
  mutate(outcome = relevel(factor(outcome), ref = "Win"))

###############################
####### START OF SERVER #######
###############################

server <- function(input, output, session) {
  # bs_themer() # for quickly scrolling through themes during development
  
  ####### FILTER DATA USING SIDEBAR FILTERS #######
  
  sel_data <- reactive({
    min_ep <- input$filter_episode[1]
    max_ep <- input$filter_episode[2]
    min_act <- input$filter_act[1]
    max_act <- input$filter_act[2]
    min_kdr <- input$filter_kdr[1] 
    max_kdr <- input$filter_kdr[2]
    min_acs <- input$filter_acs[1]
    max_acs <- input$filter_acs[2]
    min_frag <- input$filter_n_frag[1]
    max_frag <- input$filter_n_frag[2]
    
    sel <- data |>
      filter(
        map %in% input$filter_map,
        agent %in% input$filter_agent,
        episode >= min_ep & episode <= max_ep,
        act >= min_act & act <= max_act,
        kdr >= min_kdr & kdr <= max_kdr,
        acs >= min_acs & acs <= max_acs,
        num_frag >= min_frag & num_frag <= max_frag
      ) |>
      mutate(map = factor(map))
    if (input$filter_vod) {
      sel <- filter(sel, !is.na(vod))
    }
    sel
  })
  
  ####### DYNAMIC FILTER OPTIONS BASED ON DATA #######
  
  shiny::observe({
    updateSelectInput(
      session = session, 
      inputId = "filter_map", 
      choices = sort(unique(data$map)),
      selected = sort(unique(data$map))
    )
  })
  
  shiny::observe({
    updateSelectInput(
      session, 
      "filter_agent", 
      choices = sort(unique(data$agent)),
      selected = sort(unique(data$agent))
    )
  })
  
  shiny::observe({
    updateSliderInput(
      session,
      "filter_episode", 
      min = min(data$episode),
      max = max(data$episode),
      value = c(min(data$episode), max(data$episode))
    )
  })
  
  shiny::observe({
    updateSliderInput(
      session,
      "filter_act", 
      min = min(data$act),
      max = max(data$act),
      value = c(min(data$act), max(data$episode))
    )
  })
  
  shiny::observe({
    updateSliderInput(
      session,
      "filter_kdr", 
      min = min(data$kdr),
      max = max(data$kdr),
      value = c(min(data$kdr), max(data$kdr))
    )
  })
  
  shiny::observe({
    updateSliderInput(
      session,
      "filter_acs", 
      min = min(data$acs),
      max = max(data$acs),
      value = c(min(data$acs), max(data$acs))
    )
  })
  
  ####### SUMMARY TAB ELEMENTS #######
  
  # win rate plot
  output$plt_winrate <- renderPlot({
    if (nrow(sel_data()) == 0) {
      PLT_NO_DATA
    } else {
      top <- sel_data() |>
        group_by(agent) |>
        summarise(n_games = n()) |>
        arrange(desc(n_games)) |>
        slice_head(n = 3)
    
      sel_data() |>
        group_by(agent, outcome) |>
        summarise(count = n()) |>
        ungroup() |>
        filter(agent %in% top$agent) |>
        pivot_wider(
          id_cols = agent, 
          names_from = outcome, 
          values_from = count
          ) |>
        left_join(top) |>
        mutate(winrate = Win / n_games) |>
        arrange(desc(n_games)) |>
        mutate(agent = factor(agent, levels = unique(agent))) |> # reorder bars
        
        ggplot(aes(x = agent, y = winrate)) +
        geom_col(width = 0.5, fill = lighten(VAL_BLACK, 0.5)) +
        geom_hline(yintercept = 0.5, linewidth = 1, color = color_line) +
        geom_label(
         aes(y = winrate, label = glue("{n_games} games")), 
         vjust = 1,
         fontface = "bold",
         size = 4.5,
         color = VAL_BLACK,
         label.size = 0,
         nudge_y = 0.1
        ) +
        coord_cartesian(ylim = c(0,1)) +
        theme_minimal(base_size = PLOT_FONT_SIZE) +
        labs(
         x = element_blank(),
         y = "Win rate",
         title = "Win rate of most-played agents"
        ) +
        theme(
          text = element_text(family = "Inter"),
          axis.text = element_text(size = PLOT_FONT_SIZE - 3),
          plot.background = element_blank(),
          panel.background = element_blank(),
          panel.grid.minor = element_blank(),
          panel.grid.major.x = element_blank()
        )
    }
  })
  
  # scatter plot between headshot percent and kill-death ratio
  output$plt_headshot_kdr <- renderPlot({
    if (nrow(sel_data()) == 0) {
      PLT_NO_DATA
    } else {
      sel_data() |>
        filter(outcome != "Draw") |>
        ggplot(aes(x = headshot_pct, y = kdr, color = outcome)) +
        geom_point(size = 2, alpha = 0.3) +
        geom_smooth(method = "lm", se = FALSE) +
        scale_color_manual(values = pal_win_loss) +
        theme_minimal(base_size = PLOT_FONT_SIZE) +
        labs(
          x = "Headshot %",
          y = "Kill / death ratio",
          title = "KDR vs headshot percentage"
          ) +
        theme(
          text = element_text(family = "Inter"),
          legend.position = "top",
          legend.title = element_blank(),
          axis.text = element_text(size = PLOT_FONT_SIZE - 3),
          plot.background = element_blank(),
          panel.background = element_blank()
        )
    }
  })
  
  # map kdr distribution
  output$plt_map_kdr <- renderPlot({
    if (nrow(sel_data()) == 0) {
      PLT_NO_DATA
    } else {
      sel_data() |>
        ggplot(aes(x = kdr, y = rev(map))) +
        geom_boxplot(color = VAL_BLACK) +
        geom_vline(xintercept = 1, linewidth = 0.8, color = color_line) +
        scale_x_continuous(breaks = 0:round(max(sel_data()$kdr), 0)) +
        theme_minimal(base_size = PLOT_FONT_SIZE) +
        labs(
          x = "Kill / death ratio",
          y = element_blank(),
          title = "Kill / death ratio by map"
        ) +
        theme(
          text = element_text(family = "Inter"),
          legend.position = "top",
          legend.title = element_blank(),
          axis.text = element_text(size = PLOT_FONT_SIZE - 3),
          panel.grid.minor = element_blank(),
          panel.grid.major.y = element_blank()
        )
    }
  })
  
  # damage delta distribution plots
  output$plt_dmg_delta <- renderPlot({
    if (nrow(sel_data()) == 0) {
      PLT_NO_DATA
    } else {
      sel_data() |>
        filter(outcome != "Draw") |>
        ggplot(aes(x = avg_dmg_delta, fill = outcome)) + 
        geom_density(alpha = 0.4, color = VAL_BLACK) +
        geom_vline(xintercept = 0, linewidth = 1, color = color_line) +
        theme_minimal(base_size = PLOT_FONT_SIZE) +
        scale_fill_manual(values = pal_win_loss) +
        labs(
          x = "Average damage delta",
          y = element_blank(),
          title = "Damage delta distribution"
        ) +
        theme(
          text = element_text(family = "Inter"),
          legend.position = "top",
          legend.title = element_blank(),
          axis.text = element_text(size = PLOT_FONT_SIZE - 3),
          plot.background = element_blank(),
          panel.background = element_blank(),
          panel.grid.minor = element_blank(),
          panel.grid.major.x = element_blank()
        )
    }
  })
  
  ####### MODEL TAB ELEMENTS #######
  
  # split data into testing/training data
  data_split <- reactive({
    cols <- unname(model_options[input$model_factors])
    model_data <- sel_data() |>
      filter(outcome != "Draw") |>
      select(c(outcome, cols)) |>
      mutate(
        outcome = factor(outcome, levels = c("Win", "Loss")),
        outcome = relevel(outcome, ref = "Win") 
      )
    initial_split(model_data, prop = input$prop_train / 100)
  })
  
  train_data <- reactive({training(data_split())})
  test_data <- reactive({testing(data_split())})
  
  # construct the model
  model <- reactive({
    logistic_reg() |>
      set_engine("glm") |>
      set_mode("classification") |>
      fit(outcome ~ ., data = train_data())
  })
  
  # find significant factors
  output$significant_factors <- renderDT({
    alpha <- input$model_alpha
    tidy(model()) |>
      filter(p.value < alpha) |>
      arrange(p.value) |>
      mutate(across(2:5, signif, digits = 3)) |>
      select(term, estimate, p.value) |>
      clean_names(case = "sentence")
  }, options = list(dom = "t"))
  
  # predict with the model
  preds <- reactive({predict(model(), test_data(), type = "class")$.pred_class})
  pred_probs <- reactive({predict(model(), test_data(), type = "prob")})
  
  results <- reactive({
    test_data() |>
      select(outcome) |>
      bind_cols(preds()) |>
      bind_cols(pred_probs()) |>
      rename(truth = "outcome", predicted = "...2")
  })
  
  # create confusion matrix
  conf_matrix <- reactive({
    mat <- conf_mat(results(), truth = truth, estimate = predicted)$table
    mat |>
      as.matrix()
  })
  
  output$conf_matrix <- renderDT({
    conf_matrix() |>
      datatable(
        rownames = FALSE,
        options = list(dom = "t")
      )
  })
  
  # get model performance stats
  output$model_acc <- renderText({
    tp <- conf_matrix()[1,1]
    total <- sum(conf_matrix())
    paste0(round((tp / total), 3) * 100, "%")
  })
  
  # get model performance stats
  output$training_points <- renderText({
    sum(conf_matrix())
  })
  
  output$model_acc <- renderText({
    tp <- conf_matrix()[1,1]
    tn <- conf_matrix()[2,2]
    total <- sum(conf_matrix())
    paste0(round(((tp + tn) / total), 3) * 100, "%")
  })
  
  output$model_precision <- renderText({
    tp <- conf_matrix()[1,1]
    fp <- conf_matrix()[2,1]
    paste0(round(tp / (tp + fp), 3) * 100, "%")
  })
  
  # plot the ROC curve with AOC values
  output$roc_curve <- renderPlot({
    auc <- roc_auc(results(), truth = truth, .pred_Win)$.estimate
    results() |>
      roc_curve(truth = truth, .pred_Win) |>
      ggplot(aes(x = 1 - specificity, y = sensitivity)) +
      geom_path(linewidth = 1) +
      geom_abline(lty = 3) +
      coord_equal() +
      theme_minimal(base_size = PLOT_FONT_SIZE) +
      labs(
        x = "1 - Specificity",
        y = "Sensitivity",
        title = paste0("ROC Curve (AUC = ", round(auc, 3), ")")
      ) +
      theme(axis.text = element_text(size = PLOT_FONT_SIZE - 3))
  })
  
  ####### DATA TAB ELEMENTS #######
  
  # output raw data table
  output$data_table <- renderDT({
    sel_data() |>
      select(!c(vod)) |>
      mutate(date = format(lubridate::ymd(date), "%m-%d-%Y")) |>
      clean_names(case = "sentence")
    },
    rownames = FALSE,
    options = list(scrollX = TRUE)
  )
  
  ####### VOD REVIEW TAB ELEMENTS #######
  
  games_with_vods <- reactive({
    sel_data() |>
      filter(!is.na(vod))
  })
  
  shiny::observe({
    updateSelectInput(
      session = session, 
      inputId = "vod_id", 
      choices = sort(games_with_vods()$game_id),
      selected = max(games_with_vods()$game_id)
    )
  })
  
  selected_game <- reactive({ 
    sel_data() |>
      filter(game_id == input$vod_id) |>
      mutate(outcome = as.character(outcome))
  })
  
  output$vod_episode <- renderText({
    selected_game() |>
      pull(episode)
  })
  
  output$vod_rank <- renderText({
    selected_game() |>
      pull(rank)
  })
  
  output$vod_agent <- renderText({
    selected_game() |>
      pull(agent)
  })
  
  output$vod_outcome <- renderText({
    selected_game() |>
      pull(outcome)
  })
  
  output$vod_kdr <- renderText({
    selected_game() |>
      pull(kdr)
  })
  
  output$plt_mini_kdr <- renderPlot({
    curr <- selected_game() |>
      pull(kdr)
    
    data |>
      ggplot(aes(x = kdr)) +
      geom_density(alpha = 0.4, fill = VAL_BLACK, linewidth = 1) +
      geom_vline(xintercept = curr, color = VAL_RED, linewidth = 1.3) +
      theme_void()
    },
    height = 60
  )
  
  output$plt_mini_acs <- renderPlot({
    curr <- selected_game() |>
      pull(acs)
    
    data |>
      ggplot(aes(x = acs)) +
      geom_density(alpha = 0.4, fill = VAL_BLACK, linewidth = 1) +
      geom_vline(xintercept = curr, color = VAL_RED, linewidth = 1.3) +
      theme_void()
    },
    height = 60
  )
  
  output$plt_mini_headshot <- renderPlot({
    curr <- selected_game() |>
      pull(headshot_pct)
    
    data |>
      ggplot(aes(x = headshot_pct)) +
      geom_density(alpha = 0.4, fill = VAL_BLACK, linewidth = 1) +
      geom_vline(xintercept = curr, color = VAL_RED, linewidth = 1.3) +
      theme_void()
    },
    height = 60
  )
  
  output$plt_mini_avg_dmg <- renderPlot({
    curr <- selected_game() |>
      pull(avg_dmg)
    
    data |>
      ggplot(aes(x = avg_dmg)) +
      geom_density(alpha = 0.4, fill = VAL_BLACK, linewidth = 1) +
      geom_vline(xintercept = curr, color = VAL_RED, linewidth = 1.3) +
      theme_void()
    },
    height = 60
  )
  
  output$vod_acs <- renderText({
    selected_game() |>
      pull(acs)
  })
  
  output$vod_headshot <- renderText({
    selected_game() |>
      pull(headshot_pct)
  })
  
  output$vod_avg_dmg <- renderText({
    selected_game() |>
      pull(avg_dmg)
  })
  
  output$vod_window <- renderUI({
    vod_url <- selected_game() |>
      pull(vod)
    
    # convert vod url to embed-friendly version
    embed_url <- vod_url |>
      str_replace("youtu.be", "youtube.com/embed")
    
    tags$iframe(src = embed_url, height = "500", allowfullscreen = "TRUE")
  })
}