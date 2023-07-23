#!/bin/bash

check_dependencies() {
  if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    sudo apt-get update
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
  fi

  if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose not found. Installing Docker Compose..."
    sudo apt-get update
    sudo apt-get install -y docker-compose
  fi
}

create_wordpress_site() {
  read -p "Enter the site name (e.g., example.com): " site_name
  echo "Creating WordPress site $site_name..."

  # Create docker-compose.yml file
  cat <<EOF > docker-compose.yml
version: '3'
services:
  mysql:
    image: mysql:5.7
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: root_password
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpress_password
  wordpress:
    image: wordpress:latest
    restart: always
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: mysql
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress_password
      WORDPRESS_DB_NAME: wordpress
  php:
    image: php:latest
    container_name: php
    volumes:
      - ./html:/var/www/html
    restart: always
EOF

  # Create /etc/hosts entry
  echo "127.0.0.1    $site_name" | sudo tee -a /etc/hosts

  # Start containers
  sudo docker-compose up -d

  # Check site status
  sleep 10
  if sudo docker ps | grep -q "wordpress"; then
    echo "WordPress site $site_name is up and running."
    read -p "Do you want to open the site in a browser? (y/n): " choice
    if [ "$choice" = "y" ]; then
      apt-get install --reinstall xdg-utils -y
      apt-get install w3m -y
      xdg-settings --list
      update-alternatives --config www-browser 
      xdg-open "http://$site_name"
    fi
  else
    echo "Error: Failed to start the WordPress site."
  fi
}

enable_disable_site() {
  read -p "Enter the site name to enable/disable (e.g., example.com): " site_name
  if sudo docker-compose ps | grep -q "$site_name"; then
    echo "Stopping the $site_name containers..."
    sudo docker-compose stop
  else
    echo "Starting the $site_name containers..."
    sudo docker-compose start
  fi
}

delete_site() {
  read -p "Enter the site name to delete (e.g., example.com): " site_name
  echo "Deleting WordPress site $site_name..."
  sudo docker-compose down --volumes
  sudo sed -i "/$site_name/d" /etc/hosts
}

case "$1" in
  create)
    check_dependencies
    create_wordpress_site
    ;;
  enable-disable)
    check_dependencies
    enable_disable_site
    ;;
  delete)
    delete_site
    ;;
  *)
    echo "Usage: $0 {create|enable-disable|delete}"
    exit 1
    ;;
esac
