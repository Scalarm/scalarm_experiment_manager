Rails.configuration.r_interpreter.eval("if(!require(AlgDesign, quietly=TRUE)){
                                          install.packages(\"AlgDesign\", repos=\"http://cran.rstudio.com/\", quiet=TRUE)
                                        }")