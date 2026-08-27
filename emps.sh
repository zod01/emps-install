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
DATBASE_FILE="/var/virtualizor/dbbackups"
RESTORE_DB="/usr/local/emps/bin/php /usr/local/virtualizor/scripts/db_restore.php"

# checking if emps is present or not
if [[ ! -d $EMPS ]]; then
  echo "Installing emps and configured database as well, since emps got removed from server so the database has removed as well..."
  wget --no-check-certificate -N -O /usr/local/virtualizor/EMPS.tar.gz "https://$mirror_url/emps.php?latest=1&arch=x86_64"  -q  --show-progress --progress=dot 2>&1
  # Extract EMPS
  echo "Extracting emps under $EMPS"
  mkdir /usr/local/emps
  tar -xvzf /usr/local/virtualizor/EMPS.tar.gz -C /usr/local/emps >>/dev/null
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

  if ! $MYSQL -h $DBhost -u $DBuser $DATABASE >/dev/null 2>&1; then
    echo "Unable to select database"
  fi

  # Setting up database password and creating virttualizor database
  echo "Setting up database password and creating virtualizor database......"
  $MYSQL -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$DBpass'); FLUSH PRIVILEGES;" 2>&1

  $MYSQL -h $DBhost -u $DBuser -p$DBpass -e "DROP DATABASE IF EXISTS \`$DATABASE\`;"
  $MYSQL -h $DBhost -u $DBuser -p$DBpass -e "CREATE DATABASE \`$DATABASE\`;"

  $MYSQLCTL restart

  $MYSQL -h "$DBhost" -u "$DBuser" -p"$DBpass" "$DATABASE" <"$SQL_FILE" >/dev/null 2>&1

  # checking if the mysql is connecting able show tables
  if ! $MYSQL -h "$DBhost" -u "$DBuser" -p"$DBpass" "$DATABASE" -e "SHOW TABLES;" >/dev/null 2>&1; then
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


# Restore Database from backup
if [[ -n "$(ls -A "$DATBASE_FILE" 2>/dev/null)" ]]
then
  echo "Database backups found on the server...."
  echo "If files are listing below are too older and you have latest, then you can skip restore and restore database manually later"
  echo ""
  ls -lh "$DATBASE_FILE"
  echo ""
  echo ""
  echo "Select database file for restore:"
  echo "1) To restore"
  echo "2) Skip"
  read -p "Enter you choice (1-2): " choice

  case "$choice" in
    1)
      PS3="Choose a file (enter a number): "
      files=( "$DATBASE_FILE"/* )

      select file in "${files[@]}"; do
        if [[ -n "$file" ]]
        then
          SELECTED_FILE=(basename "$file")
          echo "You have selected: $SELECTED_FILE"
          echo "Restoring database from $SELECTED_FILE"
          cd
          $RESTORE_DB "$SELECTED_FILE"
          echo "Restored successfully..."
          break
        else
          echo "Invaild choice, try again"
        fi
      done
      ;;
    2)
      echo "Skipping restore,"
      SELECTED_FILE=""
      ;;
    *)
      echo "Invaild options"
      echo "Emps has been installed successfully, but unable to restore database. you can restore it manually"
      exit 1
      ;;
    esac
 echo "Restored successfully..."
else
  echo "No database backups founds on the server!"
  exit 0
fi
