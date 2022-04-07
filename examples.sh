# #master
# docker exec -it mysql_master bash
# mysql -u root -p'111' mydb
# mysql> create table if not exists code(code int);
# mysql> insert into code values (100), (200);


# #slave
# docker exec -it mysql_slave bash
# mysql -u root -p'111' mydb
# mysql> select * from code;

while true;do echo '.';sleep 1;done &
sleep 42
kill $!; trap 'kill $!' SIGTERM
echo done