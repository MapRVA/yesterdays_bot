FROM rocker/r2u:latest

RUN Rscript -e "install.packages(c('httr2', 'rvest', 'magick', \
  'atrrr', 'webshot2', 'rtoot'))"

RUN apt install wget && \
  wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
  apt install -y ./google-chrome-stable_current_amd64.deb