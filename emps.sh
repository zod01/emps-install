#!/bin/bash

source /etc/os-release

EMPS="/usr/local/emps"
mirror_url=files.softaculous.com
FILEREPO=https://files.virtualizor.com

UNIVERSAL_FILE="/usr/local/virtualizor/universal.php"
MYSQL="/usr/local/emps/bin/mysql"
DATABASE="virtualizor"
DBhost="localhost"
DBuser="root"
MYSQLCTL="/usr/local/emps/bin/mysqlctl"
SQL_FILE="/usr/local/virtualizor/virtualizor.sql"
DBpass=$(grep "\['dbpass'\]" "$UNIVERSAL_FILE" | cut -d"'" -f4)
DATBASE_FILE="/var/virtualizor/dbbackups/"
RESORE_DB="/usr/local/emps/bin/php /usr/local/virtualizor/scripts/db_restore.php"

# checking if emps is present or not
if [[ ! -d $EMPS ]]; then
    echo "Installing emps and configured database as well, since emps got removed from server so the database has removed as well..."
    wget --no-check-certificate  -N -O /usr/local/virtualizor/EMPS.tar.gz "https://$mirror_url/emps.php?latest=1&arch=x86_64" >/dev/null 2>&1
    # Extract EMPS
    echo "Extracting emps under $EMPS"
    mkdir /usr/local/emps
    tar -xvzf /usr/local/virtualizor/EMPS.tar.gz -C /usr/local/emps >> /dev/null
    rm -rf /usr/local/virtualizor/EMPS.tar.gz


  # creating symlink 
    echo "creating symlink for required files"
    ln -s /usr/local/virtualizor/conf/emps/php-fpm.conf /usr/local/emps/etc/php-fpm.conf
    ln -s /usr/local/virtualizor/conf/emps/nginx.conf /usr/local/emps/etc/nginx/nginx.conf
    ln -s /usr/local/virtualizor/conf/emps/php.ini /usr/local/emps/etc/php.ini
    ln -s /usr/local/virtualizor/conf/emps/my.cnf /usr/local/emps/etc/my.cnf

    
    # Setup virtulizor database and setting up root password for database
      $MYSQLCTL restart
      sleep 5

    if  ! $MYSQL -h $DBhost -u $DBuser $DATABASE >/dev/null 2>&1; then
      echo "Unable to select database"
    fi
      
  # Setting up database password and creating virttualizor database
  echo "Setting up database password and creating virtualizor database......"
      $MYSQL -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$DBpass'); FLUSH PRIVILEGES;" 2>&1

      $MYSQL -h $DBhost -u $DBuser -p$DBpass -e "DROP DATABASE IF EXISTS \`$DATABASE\`;"
      $MYSQL -h $DBhost -u $DBuser -p$DBpass -e "CREATE DATABASE \`$DATABASE\`;"

      $MYSQLCTL restart 

      $MYSQL -h "$DBhost" -u "$DBuser" -p"$DBpass" "$DATABASE" < "$SQL_FILE" >/dev/null 2>&1

   # checking if the mysql is connecting able show tables
      if  ! $MYSQL -h "$DBhost" -u "$DBuser" -p"$DBpass" "$DATABASE" -e "SHOW TABLES;" >/dev/null 2>&1 ; then
        echo "Unable to select database 2"
        exit 1
      fi
      echo "Database setup completed successfully"
      systemctl restart virtualizor
      echo "Emps successfully installed on the server!! "
    else
      echo "Emps is present"
      exit 0
fi


# Restoring database 
if ls -A "$DATBASE_FILE" >/dev/null 2>&1; then
  echo "Database backup files found on the server..."

  SELECTED_FILE=""

  # Checking fzf installed 
  if command -v fzf >/dev/null 2>&1; then
    echo "fzf is installed."
    SELECTED_FILE=$(ls -1 $DATBASE_FILE | fzf --prompt="Select file that you want to restore:  ")
  else
    echo "fzf is not installed, so installing fzf for better output."

      # checking host os 
      if [[ "$ID" == "almalinux" || "$ID" == "centos" || "$ID" == "rocky" ]]; then
        echo "Detected $ID"
        yum install epel-release -y >/dev/null 2>&1
        yum install fzf -y >/dev/null 2>&1

        if [[ $? -eq 0 ]]; then
          echo "fzf is installed now"
          SELECTED_FILE=$(ls -1 $DATBASE_FILE | fzf --prompt="Select file that you want to restore:  ")
        else
          echo "Failed to installed fzf. so going furter steps,"
        fi

      elif [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]
      then
        apt update -y >/dev/null 2>&1 && apt install fzf -y >/dev/null 2>&1

        if [[ $? -eq 0 ]]; then
          echo "fzf is installed now"
          SELECTED_FILE=$(ls -1 $DATBASE_FILE | fzf --prompt="Select file that you want to restore:  ")
        else
          echo "Failed to install fzf"
        fi
      fi



      # Manully copy file
      if [[ -z "$SELECTED_FILE" ]]
      then
        echo "Available backup files:"
        ls -1 $DATBASE_FILE
      echo "you will have to manually copy the file name paste it.."
      fi 
      read -p "Please paste file name so will be proceed to restoring.." SELECTED_FILE
      if [[ -z "$SELECTED_FILE" ]]
      then echo "NO filename entered"
        exit 1
      fi
    fi


  echo "You have selected $SELECTED_FILE"
  read -p "Do you want to restore database?  (yes/no)" ask
    if [[ $ask == "yes" || $ask == "YES" ]]; then
      $RESORE_DB $SELECTED_FILE >/dev/null 2>&1
      echo "Restored successfully..."
    else
      echo "Restore cancelled"
      exit 0
    fi
else
  echo "NO database backup found the server, so if you have lastest database then you can upload it to $DATBASE_FILE and then restore it.."
fi
