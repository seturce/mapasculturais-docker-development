

# WINDOWS
     1 - INSTALL Docker for windows
     2 - INSTALL GIT for windows 
          Selected Enable symbolic links 
          Selected Checkout as-is / Commit Unix-Style line endings 
     3 - Download mapas-docker
     4 - Execute following comands
          4.1 - Execute in folder ./www/ $ git clone -c core.symlinks=true https://github.com/mapasculturais/mapasculturais.git
          4.2 - UPDATE AND COPY config.php TO  www/mapasculturais/src/protected/application/conf
     5 - Execute following comands in root folder
          5.1 $ docker-compose -f docker-compose.yml build
          5.2 $ docker-compose -f docker-compose.yml up ( -d ) (Detached mode - Run containers in the background)     
     6 - Access http://localhost:8080 in your browser

# LINUX 
     1 - INSTALL Docker 
     2 - Download mapas-docker
     3 - Execute following comands
          3.1 - Execute in folder ./www/ $ git clone  https://github.com/mapasculturais/mapasculturais.git
          3.2 - UPDATE AND COPY config.php TO  www/mapasculturais/src/protected/application/conf
     4 - Execute following comands in root folder
          4.1 $ docker-compose -f docker-compose.yml build
          4.2 $ docker-compose -f docker-compose.yml up ( -d ) (Detached mode - Run containers in the background)
     5 - Access http://localhost:8080 in your browser 
