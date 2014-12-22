Rails.configuration.r_interpreter.eval(
    ".libPaths(c(\"#{Dir.pwd}/r_libs\", .libPaths()))
    if(!require(AlgDesign, quietly=TRUE)){
      install.packages(\"AlgDesign\", repos=\"http://cran.rstudio.com/\")
    }")