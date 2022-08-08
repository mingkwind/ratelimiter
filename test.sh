a=0
while [ $a -le 100 ]
do
curl http://localhost/check
a=$[a+1]
done