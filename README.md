# Corona worldwide analysis since first death of each country
## Intro
Script that fetches data from [ourworldindata.com](https://ourworldindata.org/coronavirus-source-data) and generates a CSV comparing corona evolution in countries by the first death day in each one of them.

## Usage
```
ruby corona.rb # implemented with ruby 2.7.0p0
```

## Files Generated
* `output.csv`: The CSV with the analysis
* `input.csv`: The CSV received from ourworldindate.com
* `output-<yyyy-mm-dd>.csv`: The output timestamped
* `input-<yyyy-mm-dd>.csv`: The input timestamped

## Also on Google Drive
You can checkout also on this [google drive folder](https://drive.google.com/drive/folders/16H1Pr0sLlR2uN0kePVXchM8yPHb_UfHp?usp=sharing). I'm updating it daily (usually around 12:00BRT).