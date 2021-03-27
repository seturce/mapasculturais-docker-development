# HOW TO DO INSTALL MAPAS DEV 
     1 - INSTALL Docker for windows
     2 - INSTALL GIT for windows 
          Selected Enable symbolic links 
          Selected Checkout as-is / Commit Unix-Style line endings 
     3 - Download mapas-docker
          3.1 $ git clone https://github.com/seturce/mapasculturais-docker-development.git
     4 - Execute following comands in root folder
          4.1 $ docker-compose build
          4.2 $ docker-compose up ( -d ) (Detached mode - Run containers in the background)     
     5 - Access http://localhost:8080 in your browser
