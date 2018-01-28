#! /bin/bash

JOB=`date +%Y%m%dT%H%M%S`
JOBDIR="`pwd`/$JOB"
JOBLOG=$JOBDIR/log
MISSFIRE=$HOME/git/MiSSFire
BANK=$HOME/git/MicroBank

echo Starting benchmark $JOB in $JOBDIR
mkdir -p $JOBDIR
echo Microbank benchmark > $JOBLOG
date -R >> $JOBLOG
uname -a >> $JOBLOG
[ "`uname -s`" = "Linux" ] && cat /proc/cpuinfo > "$JOBLOG".cpuinfo
uptime >> $JOBLOG
ps -ef > "$JOBLOG".ps

function runIt {
	# $1=MTLS $2=TOKEN $3=WORKERS $4=CLIENTS
	NAME=MicroBank_w"$3"_c"$4"
	[ "$1" = "True" ] && NAME="$NAME"_MTLS
	[ "$2" = "True" ] && NAME="$NAME"_TOKEN
	echo Config command: -m $1 -t $2 -w $3 -c $4 >> $JOBLOG
	echo Job name: $NAME >> $JOBLOG
	
	echo Configuring and building for $NAME
	cd $MISSFIRE
	./configure.sh -m $1 -t $2 -w $3 -c $4 >> "$JOBLOG".build
	./build.sh -i >> "$JOBLOG".build
	./build.sh -c >> "$JOBLOG".build

	echo Starting servers
	cd $BANK/services
	./build.sh -r >> "$JOBLOG".service

	echo Waiting for services
	for x in `seq 1 20`; do
		echo Checking connection... $x/20 | tee -a "$JOBLOG".service
		(cd $BANK/client; python client_1.py >> "$JOBLOG".service ) && break
		sleep 1
	done
	echo OK, client connected successfully | tee -a "$JOBLOG".service
	echo Running client
	cd $BANK/client
	(python client.py || python client.py) >> "$JOBDIR/$NAME".result

	echo Done

	cd $BANK/services
	docker-compose -f docker-compose.yml_ logs --no-color > "$JOBDIR/$NAME".log
	docker-compose -f docker-compose.yml_ rm -f >> "$JOBDIR/$NAME".log
}


for w in 1; do # `seq 1 10`; do
	for c in 50 ; do
		for mtls in True ; do
			for token in True ; do
				runIt $mtls $token $w $c
			done
		done
	done
done

cd $BANK/services
docker-compose -f docker-compose.yml_ stop
