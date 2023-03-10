#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(tidyverse)

data <- read_delim("./Checkouts_by_Title.csv")
#Extracting years and getting rid of any extra years
data$PublicationYear <- trimws(data$PublicationYear, which = c("left"))  #gets rid of leading spaces
data <- data %>% 
  extract(PublicationYear, into = "secYear", regex = "\\d{4}.*(\\d{4})", remove = FALSE, convert = TRUE) %>%
  extract(PublicationYear,into = "UpdatedYear", regex ="(\\d{4})", remove = FALSE, convert = TRUE)
#filtering out out of place numbers from UpdatedYear
data <- data %>% 
  mutate(UpdatedYear = replace(UpdatedYear, !UpdatedYear < 2023 | !UpdatedYear >= 1863, ""), 
         secYear = replace(secYear, !secYear < 2023, ""))

#Replaces an empty spaces in firstYear with secYear data
data <- data %>%
  mutate(UpdatedYear = ifelse(UpdatedYear == "",secYear, UpdatedYear ))

#Changing UpdatedYear to be numeric instead of a character
data$UpdatedYear <- as.numeric(as.character(data$UpdatedYear))

#Gets rid of PublicationYear and secYear to leave UpdatedYear by itself
data <-  data[,-12]
data <- data[,-13]


order_vector <- c("Ascending" = 'asc', "Descending" = 'desc')

# Define UI logic
ui <- fluidPage(
  titlePanel("Seattle Public Library Checkouts"),
  tabsetPanel(
    tabPanel("Overview",
             p("This app is geared towards helping library management figure out how to stock their shelves.
               The major questions we are exploring in this project are:"),
             p("1. What are the most popular types of media being checked out?"),
             p("2. How have the total checkouts of these media types changed over time?"),
             p("3. How have the total checkouts of the two usage classes changed over time?"),
             p("4. Which months have the most and fewest checkouts?"),
             p("This dataset includes a", em("monthly"),"count of Seattle Public Library checkouts by 
                        title for physical and electronic items."),
             p("The dataset begins with checkouts that occurred in April 2005."),
             p("We have", strong(nrow(data)), "rows of data and", strong(ncol(data)), "columns."),
             p("Here are the first few rows of the dataset."),
             mainPanel(tableOutput("headData"))),
    
    tabPanel(
      "Popular Plots",
      sidebarLayout(
        sidebarPanel(
          checkboxGroupInput("type",
                             "Which material type do you want?",
                             choices = list("BOOK", "VIDEODISC", "EBOOK", "SOUNDDISC", "AUDIOBOOK"),
                             selected = list("BOOK", "VIDEODISC", "EBOOK", "SOUNDDISC", "AUDIOBOOK")
          ),
          checkboxInput("display", "Display Line", TRUE),
          radioButtons("order",
                       "What are the most popular types of media being checked out? Sort by total checkouts in the order of:",
                       order_vector,
                       selected = order_vector[2])
        ),
        mainPanel(plotOutput("popular"),
                  br(),
                  HTML('<b>Below table is: media types ordered by the number of total checkouts</b>'),
                  dataTableOutput('popular_table')),
    )),
    
    tabPanel(
      "Material Publication Data",
      sidebarLayout(
        sidebarPanel(
          p("The Seattle Public Library has a many forms of media and the amount that was released changed over time. 
            This graph allows you to select between the forms of media provided below:"),
          checkboxGroupInput("material", "Select a form of media", choices = c("AUDIOBOOK", "BOOK", "EBOOK","SOUNDDISC" , "VIDEODISC")),
          checkboxInput("publicationDisplay", "Change between line graph and bar graph", TRUE)
          
        ), 
        mainPanel(plotOutput("publication"))
      )
    ),
    
    tabPanel("Usage Class Data",
      sidebarLayout(
        sidebarPanel(
          p("There are two usage types that are accounted for in the Seattle Public Library,", strong("Physical"), 
            "and", strong("Digital."), "\nThe following plot can display these types, and show a",
            em("trend line"), "corresponding to its type."),
          checkboxInput("usageTypeDisplay", "Display Trend line", F),
          checkboxGroupInput("usagetype",
                             "Which usage type do you want to see?",
                             choices = list("Physical", "Digital"),
                             selected = list("Physical", "Digital")
            
          )
        ),
        mainPanel(
          plotOutput("usageclassplot"),
          textOutput("usageclass_summary"),
          textOutput("usageclass_max"),
          p(),
          p(strong("Why do we want to know this information?")),
          p("We learn the valuable information regarding which types are most popular, and we can predict the
            most purchased types in the future by use of the", em("trend line"), "which allows for the Seattle
            Public Library, and other libraries similar to it, to understand and accomodate for the types according 
            to the relative distributions of checkouts they have.")
        )
      )
    ),
    
    #checkout by month
    tabPanel(
      "Book Checkouts by Month",
      h1(strong("Checkouts by month")),
      sidebarLayout(
        sidebarPanel(
          selectInput(
            inputId = "CheckoutYear",
            label = "Select Year:",
            choices = sort(unique(data$CheckoutYear)),
            selected = NULL
          ),
          sliderInput(
            inputId = "month_range",
            label = "Select month range:",
            min = 1,
            max = 12,
            value = c(1, 12),
            step = 1
          )
        ),
        mainPanel(
          p("This data table and bar graph explains the question Which months have the most and fewest checkouts.
            The data table and graph allows you to select specific year and month range."),
          tableOutput("table1"),
          plotOutput("plot1"),
          hr(),
        )
      )
    ),
    tabPanel("Conclusion", p("A notable takeaway from this project is that there has been a clear upward trend in the number checkouts of Ebooks and Audiobooks."),
             p("The broader conclusion is that there has a been an upward trend in the number of checkouts of digital types of media."),
             p("The data quality was reasonable since there were no rows with NA values in the columns we were using. For the publication year column,
               we had to do some cleaning to make sure the column was a single year value."),
             p("We think the dataset is unbaised, but since the data comes from a single library, we are not sure if it is an accurate representation of all libraries."),
             p("In the future, we might use hypothesis tests to see answer the overview questions. We might also use data from multiple libraries to get a more accurate estimation."),
             p("The following table shows digital sales by year in ascending order."),
             mainPanel(tableOutput("dig")))
  )
)

# Define server logic
server <- function(input, output) {
  # Overview
  output$headData <- renderTable({head(data)})

  # Popular Plot
  output$popular <- renderPlot({
    if(input$display) {
      data %>% filter(MaterialType %in% input$type, CheckoutYear != 2023) %>%
        group_by(CheckoutYear, MaterialType) %>%
        summarize(totalCheckouts = sum(Checkouts)) %>%
        ggplot(aes(x=CheckoutYear, y=totalCheckouts)) +
        geom_point(aes(color=MaterialType)) +
        geom_line(aes(color=MaterialType)) +
        labs(x = "Year", y = "Total Checkouts", title = "Scatterplot of 5 most popular types of media")
    }
    else {
      data %>% filter(MaterialType %in% input$type, CheckoutYear != 2023) %>%
        group_by(CheckoutYear, MaterialType) %>%
        summarize(totalCheckouts = sum(Checkouts)) %>%
        ggplot(aes(x=CheckoutYear, y=totalCheckouts)) +
        geom_point(aes(color=MaterialType)) +
        labs(x = "Year", y = "Total Checkouts", title = "Scatterplot of 5 most popular types of media")
    }
  })
  
  # Popular interactive table
  output$popular_table <- renderDataTable({
    t <- data %>% group_by(MaterialType) %>% summarise(total_checkouts = sum(Checkouts))
    if (input$order == 'asc') {
      t <- t %>% arrange(total_checkouts)
    } else if (input$order == 'desc') {
      t <- t %>% arrange(desc(total_checkouts))
    }
    return(t)
  })
  
  #Publication Plot
  output$publication <- renderPlot({

    if(input$publicationDisplay){
      data %>% 
        group_by(UpdatedYear, MaterialType) %>%
        filter(MaterialType %in% input$material, !is.na(UpdatedYear)) %>% 
        summarise(media_count = length(Title)) %>% 
      ggplot(aes(UpdatedYear, media_count, fill = MaterialType))+
      geom_col()+
      scale_x_continuous(breaks = seq(0, 2022, 4))+
      theme(axis.text = element_text(size = 10, hjust = 1, angle = 45), legend.key.size = unit(0.3, "line"))+
      labs(title = "Amount of Media Released Yearly",x = "Year",y = "Amount of Media Released",fill = "Material Type")
        
    }
    else{
      data %>% 
        group_by(UpdatedYear, MaterialType) %>% 
        filter(MaterialType %in% input$material, !is.na(UpdatedYear)) %>%
        summarise(media_count = length(Title)) %>% 
      ggplot(aes(UpdatedYear, media_count, col = MaterialType))+
      geom_line()+
      scale_x_continuous(breaks = seq(0, 2022, 4))+
      theme(axis.text = element_text(size = 10, hjust = 1, angle = 45), legend.key.size = unit(0.3, "line"))+
      labs(title = "Amount of Media Released Yearly",x = "Year",y = "Amount of Media Released",fill = "Material Type")
    }
    

  })
  
  # Usage Class Data
  usageclassdata <- reactive({
    data %>% 
      filter(UsageClass %in% input$usagetype, CheckoutYear != 2023) %>% 
      group_by(CheckoutYear, UsageClass) %>% 
      summarize(checkoutsum = sum(Checkouts))
  })
  
  output$usageclassplot <- renderPlot({
    if (input$usageTypeDisplay) {
      usageclassdata() %>% 
        ggplot(aes(CheckoutYear, checkoutsum, col = UsageClass)) + geom_point() + geom_line() +
        geom_smooth(method = lm, se = F) +
        labs(x = "Time", y = "Number of Checkouts", col = "Type")
    } else {
      usageclassdata() %>% 
        ggplot(aes(CheckoutYear, checkoutsum, col = UsageClass)) + geom_point() + geom_line() +
        labs(x = "Time", y = "Number of Checkouts", col = "Type")
    }
  })
  
  output$usageclass_summary <- renderText({
    usageclassrows <- usageclassdata() %>% 
      nrow()
    if (usageclassrows != 0)
      paste("Number of years observed:", usageclassrows)
  })
  
  output$usageclass_max <- renderText({
    max <- usageclassdata()$checkoutsum %>% 
      max()
    if(!is.infinite(max)) {
      paste("Maximum checkouts of", max, "at year", usageclassdata()$CheckoutYear[usageclassdata()$checkoutsum == max])
    } else {
      ""
    }
  })
  
  # Digital by year
  output$dig <- renderTable({
    data %>% filter(UsageClass == "Digital") %>%
      group_by(CheckoutYear) %>%
      summarize(checkoutsum = sum(Checkouts))
  })
  
  #checkout by month data table
  table_data <- reactive({
    data %>%
      filter(CheckoutYear == input$CheckoutYear) %>%
      filter( CheckoutMonth >= input$month_range[1] & CheckoutMonth <= input$month_range[2]) %>%
      group_by(CheckoutMonth) %>%
      summarize(Total_Checkout = as.integer(sum(Checkouts)), unit = "books") %>%
      mutate(Month = month.name[CheckoutMonth]) %>%
      select(Month, Total_Checkout)
  })
  
  output$plot1 <- renderPlot({
    ggplot(table_data(), aes(x = Month, y = Total_Checkout, fill = Month)) +
      geom_bar(stat = "identity", fill = "purple") +
      xlab("Month") +
      ylab("Checkouts") +
      ggtitle("Book checkouts by month") +
      scale_x_discrete(limits = month.name)
  })
  output$table1 <- renderTable({
    table_data()
  }, digits = 0)
}

# Run the application 
shinyApp(ui = ui, server = server)
