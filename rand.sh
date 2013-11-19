#!/bin/bash

infile=rand.mfd
tmpfile=rand.txt
outfile=rand_out.mfd

[ -e $infile ] || { echo No such file; exit 1; }
echo -n > $tmpfile

function hex () {
    local h=$(dc -e "16o$1p")
    [ $((${#h}%2)) -eq 0 ] || h="0"$h
    echo $h
}

function dec () {
    dc -e "16i$1p"
}

# rand from to
function rand () {
    local rx=$(dd if=/dev/urandom bs=1 count=4 2>/dev/null|xxd -u -p)
    echo $(($(dec $rx) % $(($2-$1+1)) + $1))
}

function reader () {
    case $1 in
         0) echo 65 ;;
         1) echo 66 ;;
         2) echo 67 ;;
         3) echo 00 ;;
         4) echo 68 ;;
         5) echo 6A ;;
         6) echo 6C ;;
         7) echo 13 ;;
         8) echo 14 ;;
         9) echo 15 ;;
        10) echo 2B ;;
        11) echo 02 ;;
    esac
    echo 65
}

write_pos=0
write_cb=0

# write start reverse data
function write () {
    local start=$(dec $1)
    local count=$((${#3}/2))
    xxd -u -p -s $write_pos -l $(($start-$write_pos)) $infile >> $tmpfile
    write_pos=$(($start+$count))
    [ $2 -eq 0 ] && echo -n "$3" >> $tmpfile
    local data=$(xxd -u -p -s $start -l $count $infile)
    local pos=0
    while [ $count -gt 0 ]; do
        pos=$((($count-1)*2))
        write_cb=$(($write_cb ^ $(dec ${data:$pos:2}) ^ $(dec ${3:$pos:2})))
        [ $2 -eq 0 ] || echo -n ${3:$pos:2} >> $tmpfile
        count=$(($count-1))
    done
}

# check start
function check () {
    local start=$(dec $1)
    xxd -u -p -s $write_pos -l $(($start-$write_pos)) $infile >> $tmpfile
    local cb=$(dec $(xxd -u -p -s $start -l 1 $infile))
    echo -n $(hex $(($write_cb ^ $cb))) >> $tmpfile
    write_pos=$(($start+1))
    write_cb=0
}

function nocheck () {
    write_cb=0
}

function finish () {
    xxd -u -p -s $write_pos $infile >> $tmpfile
    xxd -r -p $tmpfile > $outfile
}

function ascii () {
    local count=${#1}
    local str=""
    while [ $count -gt 0 ]; do
        str=$(hex $((${1:$(($count-1)):1}+48)))$str
        count=$(($count-1))
    done
    echo $str
}

function pad () {
    local count=$(($1-${#2}))
    local str=$2
    while [ $count -gt 0 ]; do
        str="0"$str
        count=$(($count-1))
    done
    echo $str
}

function invert () {
    local count=0
    local str=""
    while [ $count -lt ${#1} ]; do
        str=$str$(hex $((0x${1:$count:2} ^ 255)))
        count=$(($count+2))
    done
    echo $str
}

id=$(rand 1000000 2000000)
matrnum=$(rand 170000 200000)
bibo="31000600"$(rand 0 999)
[ $# -eq 1 ] && money=$1 || money=$(rand 800 1300)
last_load_day=$(rand 0 14)
last_buy_day=$(rand 0 $last_load_day)
last_load_time=$(rand 11 14)
last_buy_time=$(rand 11 14)
last_load_min=$(rand 0 59)
last_buy_min=$(rand 0 59)
last_load_val=2000
last_load_reader=$(rand 0 11)
last_buy_reader=$(rand 0 11)
buy_counter=$(rand 0 150)

today_year=$(date +%Y)
today_mon=$(date +%-m)
today_day=$(date +%-d)

[ $last_load_day -ge $today_day ] && last_load_day=$(($today_day-1))
[ $last_buy_day -ge $today_day ] && last_buy_day=$(($today_day-1))
[ $today_mon -lt 4 ] && { mvb_mon=3; mvb_year=$today_year; }
[ $today_mon -ge 4 -a $today_mon -lt 10 ] && { mvb_mon=9; mvb_year=$today_year; }
[ $today_mon -gt 10 ] && { mvb_mon=4; mvb_year=$(($today_year+1)); }

write 27 1 $(hex $id)
check 2F

write 40 1 $(pad 4 $(hex $money))
write 42 0 0000
write 44 1 $(invert $(pad 4 $(hex $money)))
write 46 0 FFFF
write 48 1 $(pad 4 $(hex $money))
write 4A 0 0000
nocheck

write 50 1 $(pad 4 $(hex $money))
write 52 0 0000
write 54 1 $(invert $(pad 4 $(hex $money)))
write 56 0 FFFF
write 58 1 $(pad 4 $(hex $money))
write 5A 0 0000
nocheck

write 81 0 $(reader $last_load_reader)
write 82 0 $(hex $(($today_day-$last_load_day)))
write 83 0 $(hex $today_mon)
write 84 0 $(hex $today_year)
write 86 0 $(hex $last_load_time)
write 87 0 $(hex $last_load_min)
write 8A 0 $(pad 4 $(hex $last_load_val))
check 8F

write 91 0 $(reader $last_buy_reader)
write 92 0 $(hex $(($today_day-$last_buy_day)))
write 93 0 $(hex $today_mon)
write 94 0 $(hex $today_year)
write 96 0 $(hex $last_buy_time)
write 97 0 $(hex $last_buy_min)
write 9E 0 $(hex $buy_counter)
check 9F

write C0 0 30
write C1 0 $(pad 2 $mvb_mon)
write C2 0 $(pad 4 $mvb_year)
check CF

write D4 0 $matrnum
check DF

write E0 0 01
write E1 0 $(pad 2 $(($mvb_mon+1)))
write E2 0 $(pad 4 $(($mvb_year-1)))
check EF

write 141 0 $(ascii $bibo)
check 14F

finish

exit 0
